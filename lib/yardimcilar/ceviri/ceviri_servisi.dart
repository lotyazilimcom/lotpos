import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'tr.dart';
import 'en.dart';
import 'ar.dart';

// Global yardımcı fonksiyon
String tr(String key, {Map<String, String>? args}) {
  return CeviriServisi().cevir(key, args: args);
}

class CeviriServisi extends ChangeNotifier {
  static final CeviriServisi _instance = CeviriServisi._internal();
  factory CeviriServisi() => _instance;
  CeviriServisi._internal();

  String _mevcutDil = 'tr';
  Map<String, String> _mevcutCeviriler = {};
  bool _yuklendi = false;

  // Core diller (Bellekte sabit durur)
  final Map<String, Map<String, String>> _coreCeviriler = {
    'tr': trCeviriler,
    'en': enCeviriler,
    'ar': arCeviriler,
  };

  final Map<String, TextDirection> _dilYonleri = {
    'tr': TextDirection.ltr,
    'en': TextDirection.ltr,
    'ar': TextDirection.rtl,
  };

  // Dil adlarını tutan liste (Tüm diller burada listelenir)
  final Map<String, String> _dilAdlari = {
    'tr': 'Türkçe',
    'en': 'English',
    'ar': 'العربية',
  };

  Set<String> _pasifDiller = {};

  bool isDilAktif(String kod) => !_pasifDiller.contains(kod);

  String get mevcutDil => _mevcutDil;
  TextDirection get textDirection =>
      _dilYonleri[_mevcutDil] ?? TextDirection.ltr;
  bool get yuklendi => _yuklendi;

  Future<void> yukle() async {
    if (_yuklendi) return;

    // 1. Önce kayıtlı özel dillerin METADATA'sını yükle (Çevirileri belleğe alma)
    await _ozelDilleriTara();

    // 2. Sonra seçili dili belirle
    final prefs = await SharedPreferences.getInstance();
    final kaydedilmisDil = prefs.getString('dil');

    if (kaydedilmisDil != null && _dilAdlari.containsKey(kaydedilmisDil)) {
      _mevcutDil = kaydedilmisDil;
    } else {
      _mevcutDil = 'tr'; // Varsayılan dil
    }

    final pasifList = prefs.getStringList('pasif_diller');
    if (pasifList != null) {
      _pasifDiller = pasifList.toSet();
    }

    // 3. Sadece seçili dilin çevirilerini belleğe yükle
    await _dilVerisiniYukle(_mevcutDil);

    _yuklendi = true;
    notifyListeners();
  }

  Future<void> _ozelDilleriTara() async {
    try {
      if (kIsWeb) return;
      final directory = await getApplicationDocumentsDirectory();
      final languagesDir = Directory('${directory.path}/languages');

      if (!await languagesDir.exists()) {
        await languagesDir.create(recursive: true);
        return;
      }

      await for (final entity in languagesDir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final String content = await entity.readAsString();
            final Map<String, dynamic> jsonContent = jsonDecode(content);

            final languageData = jsonContent['language'];
            // Eski format veya hatalı dosyaları atla
            if (languageData == null) continue;

            final String? code =
                languageData['short_form'] ?? languageData['code'];
            final String? name = languageData['name'];
            final String? direction =
                languageData['text_direction'] ?? languageData['direction'];

            // Gerekli alanlar yoksa atla
            if (code == null || name == null) continue;

            // Core dilleri atla
            if (_coreCeviriler.containsKey(code)) continue;

            // Sadece metadata'yı kaydet, çevirileri belleğe alma!
            _dilAdlari[code] = name;
            _dilYonleri[code] = direction == 'rtl'
                ? TextDirection.rtl
                : TextDirection.ltr;
          } catch (e) {
            debugPrint('Dil dosyası taranırken hata: ${entity.path} - $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Özel diller taranırken hata: $e');
    }
  }

  Future<void> _dilVerisiniYukle(String kod) async {
    // Core dil ise direkt al
    if (_coreCeviriler.containsKey(kod)) {
      _mevcutCeviriler = _coreCeviriler[kod]!;
      return;
    }

    // Özel dil ise dosyadan oku
    try {
      if (kIsWeb) {
        // Web'de özel dil dosyası yok, sadece core diller
        _mevcutCeviriler = _coreCeviriler['tr']!;
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/languages/$kod.json');

      if (await file.exists()) {
        final String content = await file.readAsString();
        final Map<String, dynamic> jsonContent = jsonDecode(content);
        final List<dynamic> translationsList = jsonContent['translations'];

        final Map<String, String> translations = {};
        for (var item in translationsList) {
          translations[item['label']] = item['translation'];
        }

        _mevcutCeviriler = translations;
      } else {
        // Dosya yoksa varsayılan olarak TR'ye dön
        debugPrint('Dil dosyası bulunamadı: $kod');
        _mevcutCeviriler = _coreCeviriler['tr']!;
      }
    } catch (e) {
      debugPrint('Dil verisi yüklenirken hata: $e');
      _mevcutCeviriler = _coreCeviriler['tr']!;
    }
  }

  Future<void> _ozelDiliKaydet(
    String code,
    String name,
    Map<String, String> translations,
    TextDirection direction,
  ) async {
    try {
      if (kIsWeb) return;
      final directory = await getApplicationDocumentsDirectory();
      final languagesDir = Directory('${directory.path}/languages');
      if (!await languagesDir.exists()) {
        await languagesDir.create(recursive: true);
      }

      final Map<String, dynamic> jsonContent = {
        "language": {
          "name": name,
          "short_form": code,
          "language_code": "$code-$code",
          "text_direction": direction == TextDirection.rtl ? 'rtl' : 'ltr',
          "text_editor_lang": code,
        },
        "translations": translations.entries
            .map((e) => {"label": e.key, "translation": e.value})
            .toList(),
      };

      final File file = File('${languagesDir.path}/$code.json');
      await file.writeAsString(jsonEncode(jsonContent));
    } catch (e) {
      debugPrint('Dil kaydedilirken hata: $e');
    }
  }

  Future<void> _ozelDiliSilDosyadan(String code) async {
    try {
      if (kIsWeb) return;
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/languages/$code.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Dil dosyası silinirken hata: $e');
    }
  }

  Future<void> dilDegistir(String yeniDil) async {
    if (!_dilAdlari.containsKey(yeniDil)) {
      debugPrint('Desteklenmeyen dil: $yeniDil');
      return;
    }

    if (_mevcutDil == yeniDil) return;

    // Yeni dilin verilerini yükle
    await _dilVerisiniYukle(yeniDil);

    _mevcutDil = yeniDil;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dil', yeniDil);

    notifyListeners();
  }

  Future<void> dilSil(String dilKodu) async {
    if (_mevcutDil == dilKodu) return;
    if (_coreCeviriler.containsKey(dilKodu)) return;

    _dilAdlari.remove(dilKodu);
    _dilYonleri.remove(dilKodu);

    await _ozelDiliSilDosyadan(dilKodu);

    notifyListeners();
  }

  Future<void> dilGuncelle(
    String eskiKod,
    String yeniKod,
    String yeniAd,
    TextDirection yeniYon,
  ) async {
    // Eğer güncellenen dil şu anki dil ise, çevirileri bellekte tutmamız lazım
    Map<String, String>? ceviriler;

    if (eskiKod == _mevcutDil) {
      ceviriler = _mevcutCeviriler;
    } else {
      // Dosyadan oku
      try {
        if (!kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/languages/$eskiKod.json');
          if (await file.exists()) {
            final String content = await file.readAsString();
            final Map<String, dynamic> jsonContent = jsonDecode(content);
            final List<dynamic> translationsList = jsonContent['translations'];
            ceviriler = {};
            for (var item in translationsList) {
              ceviriler[item['label']] = item['translation'];
            }
          }
        }
      } catch (e) {
        debugPrint('Güncelleme sırasında dosya okuma hatası: $e');
      }
    }

    if (ceviriler == null) return;

    // Eski kaydı sil
    _dilAdlari.remove(eskiKod);
    _dilYonleri.remove(eskiKod);
    await _ozelDiliSilDosyadan(eskiKod);

    // Yeni kaydı ekle
    _dilAdlari[yeniKod] = yeniAd;
    _dilYonleri[yeniKod] = yeniYon;
    await _ozelDiliKaydet(yeniKod, yeniAd, ceviriler, yeniYon);

    // Eğer aktif dil güncellendiyse
    if (eskiKod == _mevcutDil) {
      _mevcutDil = yeniKod;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dil', yeniKod);
    }

    notifyListeners();
  }

  Future<void> yeniDilEkle(
    String kod,
    String ad,
    Map<String, String> ceviriler,
    TextDirection yon,
  ) async {
    _dilAdlari[kod] = ad;
    _dilYonleri[kod] = yon;

    await _ozelDiliKaydet(kod, ad, ceviriler, yon);

    notifyListeners();
  }

  String cevir(String key, {Map<String, String>? args}) {
    String value = key;
    if (!_yuklendi) {
      value = _coreCeviriler['tr']?[key] ?? key;
    } else {
      value = _mevcutCeviriler[key] ?? key;
      if (value == key) {
        // Fallback: önce TR, sonra EN, sonra AR
        for (final dil in ['tr', 'en', 'ar']) {
          final map = _coreCeviriler[dil];
          if (map != null && map.containsKey(key)) {
            value = map[key]!;
            break;
          }
        }
      }
    }

    if (args != null && value != key) {
      args.forEach((key, val) {
        value = value.replaceAll('{$key}', val);
      });
    }

    return value;
  }

  List<String> desteklenenDiller() {
    return _dilAdlari.keys.toList();
  }

  String dilAdi(String dilKodu) {
    return _dilAdlari[dilKodu] ?? dilKodu;
  }

  // Bu metod artık sadece aktif dil için veya core diller için anlık cevap verebilir
  // Diğer diller için null dönebilir veya dosyadan okuması gerekir.
  // Editör için kullanılıyorsa, editör açıldığında yüklenmesi daha doğru olur.
  // Şimdilik geriye uyumluluk için core dilleri ve aktif dili döndürür.
  Map<String, String>? getCeviriler(String dilKodu) {
    if (_coreCeviriler.containsKey(dilKodu)) {
      return _coreCeviriler[dilKodu];
    }
    if (dilKodu == _mevcutDil) {
      return _mevcutCeviriler;
    }
    // Diğer diller için null döner, bu durumda çağıran yerin (Editör) yüklemesi gerekir.
    // Ancak mevcut yapıda editör senkron bekliyor olabilir.
    // Editör açılırken veriyi yüklemek en doğrusu.
    // Şimdilik null dönelim, editör tarafında kontrol edelim.
    return null;
  }

  // Editör için asenkron yükleyici
  Future<Map<String, String>?> getCevirilerAsync(String dilKodu) async {
    if (_coreCeviriler.containsKey(dilKodu)) {
      return _coreCeviriler[dilKodu];
    }
    if (dilKodu == _mevcutDil) {
      return _mevcutCeviriler;
    }

    // Dosyadan oku
    try {
      if (kIsWeb) return null;
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/languages/$dilKodu.json');

      if (await file.exists()) {
        final String content = await file.readAsString();
        final Map<String, dynamic> jsonContent = jsonDecode(content);
        final List<dynamic> translationsList = jsonContent['translations'];

        final Map<String, String> translations = {};
        for (var item in translationsList) {
          translations[item['label']] = item['translation'];
        }
        return translations;
      }
    } catch (e) {
      debugPrint('Çeviri getirme hatası: $e');
    }
    return null;
  }

  Map<String, String> getTumDiller() {
    return _dilAdlari;
  }

  Future<void> dilPasifYap(String kod) async {
    if (kod == _mevcutDil) return;
    _pasifDiller.add(kod);
    await _pasifDilleriKaydet();
    notifyListeners();
  }

  Future<void> dilAktifYap(String kod) async {
    _pasifDiller.remove(kod);
    await _pasifDilleriKaydet();
    notifyListeners();
  }

  Future<void> _pasifDilleriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pasif_diller', _pasifDiller.toList());
  }
}
