import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class YapayZekaServisi {
  static final YapayZekaServisi _instance = YapayZekaServisi._internal();
  factory YapayZekaServisi() => _instance;
  YapayZekaServisi._internal();

  static const String _apiKeyKey = 'ai_api_key';
  static const String _modelKey = 'ai_model';
  static const String _modelsKey = 'ai_models_list';

  Future<void> ayarlariKaydet({
    required String apiKey,
    required String model,
    List<String>? models,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    await prefs.setString(_modelKey, model);
    if (models != null) {
      await prefs.setStringList(_modelsKey, models);
    }
  }

  Future<Map<String, dynamic>> ayarlariGetir() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    final model = prefs.getString(_modelKey);
    final models = prefs.getStringList(_modelsKey);
    return {'apiKey': apiKey, 'model': model, 'models': models};
  }

  Future<String?> apiAnahtariGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  Future<String?> modelGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey);
  }

  // Kağıt boyutunu mm olarak hesapla
  Map<String, double> _getPaperDimensions(String paperSize) {
    switch (paperSize) {
      case 'A4':
        return {'width': 210.0, 'height': 297.0};
      case 'A5':
        return {'width': 148.0, 'height': 210.0};
      case 'Continuous':
        return {'width': 240.0, 'height': 280.0};
      case 'Thermal80':
        return {'width': 80.0, 'height': 200.0};
      case 'Thermal58':
        return {'width': 58.0, 'height': 150.0};
      default:
        return {'width': 210.0, 'height': 297.0};
    }
  }

  Future<List<Map<String, dynamic>>> analizEtDokumanTaslagi({
    required Uint8List imageBytes,
    required String paperSize,
    required List<Map<String, String>> availableFields,
    double? customWidth,
    double? customHeight,
    bool isLandscape = false,
  }) async {
    final apiKey = await apiAnahtariGetir();
    final model = await modelGetir() ?? 'gemini-2.5-flash-lite';

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('AI API anahtarı ayarlanmamış.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    // Kağıt boyutlarını hesapla
    Map<String, double> dimensions;
    if (paperSize == 'Custom' && customWidth != null && customHeight != null) {
      dimensions = {'width': customWidth, 'height': customHeight};
    } else {
      dimensions = _getPaperDimensions(paperSize);
    }

    // Landscape modunda boyutları değiştir
    final pageWidth = isLandscape
        ? dimensions['height']!
        : dimensions['width']!;
    final pageHeight = isLandscape
        ? dimensions['width']!
        : dimensions['height']!;

    // Alan listesini oluştur
    final fieldsList = availableFields
        .map((e) => '${e['key']}: ${e['label']}')
        .join(', ');

    // Profesyonel ve optimize edilmiş prompt
    final prompt =
        '''You are analyzing a printed document template image to locate fillable zones.
Çıktıyı SADECE ve SADECE saf JSON array formatında ver. Markdown, code block veya başka bir metin EKLEME.

DOCUMENT: ${pageWidth.toInt()}mm x ${pageHeight.toInt()}mm ($paperSize${isLandscape ? ' Landscape' : ''})
COORDINATE SYSTEM: Origin at top-left (0,0), all values in millimeters (mm).

FIELDS TO LOCATE: $fieldsList

RULES:
- x: 0 to ${pageWidth.toInt()} (horizontal position from left edge)
- y: 0 to ${pageHeight.toInt()} (vertical position from top edge)
- width: field box width in mm
- height: field box height in mm
- x + width must not exceed ${pageWidth.toInt()}
- y + height must not exceed ${pageHeight.toInt()}
- Only include fields that have visible empty/fillable zones in the image
- For items_table, locate the table body area (exclude headers)

RETURN FORMAT (JSON Array only, no markdown):
[{"key": "field_key", "label": "Field Label", "x": 10, "y": 20, "width": 50, "height": 8}]
''';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              // Resmi önce gönder (best practice)
              {
                "inline_data": {
                  "mime_type": "image/png",
                  "data": base64Encode(imageBytes),
                },
              },
              {"text": prompt},
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 4096,
          "response_mime_type": "application/json",
        },
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Candidates kontrolü
      if (decoded['candidates'] == null ||
          (decoded['candidates'] as List).isEmpty) {
        throw Exception('AI yanıt döndürmedi.');
      }

      final candidate = decoded['candidates'][0];

      // Content kontrolü
      if (candidate['content'] == null ||
          candidate['content']['parts'] == null ||
          (candidate['content']['parts'] as List).isEmpty) {
        throw Exception('AI içerik döndürmedi.');
      }

      final String text = candidate['content']['parts'][0]['text'];

      // JSON parse et - önce direkt dene
      try {
        final parsed = jsonDecode(text);
        if (parsed is List) {
          // Koordinat validasyonu yap
          final validated = <Map<String, dynamic>>[];
          for (final item in parsed) {
            if (item is Map<String, dynamic>) {
              final x = (item['x'] as num?)?.toDouble() ?? 0;
              final y = (item['y'] as num?)?.toDouble() ?? 0;
              final w = (item['width'] as num?)?.toDouble() ?? 50;
              final h = (item['height'] as num?)?.toDouble() ?? 8;

              // Koordinatları sınırla
              validated.add({
                'key': item['key'] ?? '',
                'label': item['label'] ?? item['key'] ?? '',
                'x': x.clamp(0, pageWidth - 1),
                'y': y.clamp(0, pageHeight - 1),
                'width': w.clamp(1, pageWidth - x),
                'height': h.clamp(1, pageHeight - y),
              });
            }
          }
          return validated;
        }
      } catch (_) {
        // JSON parse başarısız, regex ile dene
      }

      // Regex ile JSON array ayıkla (greedy matching)
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (jsonMatch != null) {
        try {
          final jsonStr = jsonMatch.group(0)!;
          final parsed = jsonDecode(jsonStr);
          if (parsed is List) {
            final validated = <Map<String, dynamic>>[];
            for (final item in parsed) {
              if (item is Map<String, dynamic>) {
                final x = (item['x'] as num?)?.toDouble() ?? 0;
                final y = (item['y'] as num?)?.toDouble() ?? 0;
                final w = (item['width'] as num?)?.toDouble() ?? 50;
                final h = (item['height'] as num?)?.toDouble() ?? 8;

                validated.add({
                  'key': item['key'] ?? '',
                  'label': item['label'] ?? item['key'] ?? '',
                  'x': x.clamp(0, pageWidth - 1),
                  'y': y.clamp(0, pageHeight - 1),
                  'width': w.clamp(1, pageWidth - x),
                  'height': h.clamp(1, pageHeight - y),
                });
              }
            }
            return validated;
          }
        } catch (_) {
          // Parse hatası
        }
      }

      throw Exception('AI geçersiz JSON döndürdü: $text');
    }

    // Hata durumunda detaylı mesaj
    final errorBody = response.body;
    if (response.statusCode == 400) {
      throw Exception(
        'API isteği geçersiz. Model veya schema hatası olabilir.',
      );
    } else if (response.statusCode == 429) {
      throw Exception('API limit aşıldı. Lütfen biraz bekleyin.');
    } else if (response.statusCode == 500) {
      throw Exception('Sunucu hatası. Farklı bir model deneyin.');
    }

    throw Exception(
      'AI analizi başarısız oldu (${response.statusCode}): $errorBody',
    );
  }

  Future<Map<String, dynamic>> analizEtGiderFisi(Uint8List imageBytes) async {
    final apiKey = await apiAnahtariGetir();
    final model = await modelGetir() ?? 'gemini-1.5-flash';

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('AI API anahtarı ayarlanmamış.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    const prompt = '''
Bu bir gider fişi/faturası. Lütfen resmi analiz et ve aşağıdaki bilgileri çıkar.
Çıktıyı SADECE ve SADECE saf JSON formatında ver. Markdown, code block veya başka bir metin EKLEME.

İstenen JSON Yapısı:
{
  "baslik": "Satıcı Adı - Kısa Açıklama",
  "magaza": "Satıcı/Mağaza Adı",
  "tarih": "YYYY-MM-DD",
  "tutar": 0.00,
  "kategori": "En uygun kategori (Örn: Market, Yemek, Akaryakıt, Giyim, Elektronik, Diğer)",
  "kalemler": [
    {
      "aciklama": "Ürün Adı",
      "tutar": 0.00,
      "not": "Miktar/Birim (Varsa)"
    }
  ]
}
''';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Encode(imageBytes),
                },
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 4096,
          "response_mime_type": "application/json",
        },
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final String text =
          decoded['candidates'][0]['content']['parts'][0]['text'];

      return Map<String, dynamic>.from(jsonDecode(text));
    }

    throw Exception('AI analizi başarısız oldu: ${response.body}');
  }

  Future<Map<String, dynamic>> analizEtHizliUrun(List<Uint8List> images) async {
    final apiKey = await apiAnahtariGetir();
    final model = await modelGetir() ?? 'gemini-1.5-flash';

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('AI API anahtarı ayarlanmamış.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    const prompt = '''
Lütfen gönderilen resimleri analiz et ve içerisindeki ürün bilgilerini çıkar. 
Bu resimler bir ürün listesi, fiyat etiketi, ürünün kendisi (farklı açılardan) veya IMEI/Seri No listeleri olabilir.

KURALLAR:
1. Eğer resimler bir cihazın farklı açılarıysa (Örn: iPhone ön, arka, kutu), bunları TEK BİR ürün olarak birleştir.
2. Eğer resimlerde bir tablo/liste varsa (Örn: 50 adet iPhone 16 ve yanındaki IMEI listesi), bunları doğru miktar (stok) ve seri numaralarıyla yakala.
3. Resimdeki tüm "IMEI" veya "Seri No" bilgilerini bul ve her ürünün kendi listesine (imeiList) ekle.
4. **Görüntü Eşleştirme ve Sınıflandırma**: Sana gönderilen resimlerin sırasını (0'dan başlayarak) takip et.
   - Hangi resim hangi ürüne aitse, o resmin index numarasını ürünün `resimler` listesine bir nesne olarak ekle.
   - Nesne yapısı: `{"index": 0, "tip": "urun"}` (Eğer resim ürünün kendisi ise) veya `{"index": 1, "tip": "etiket"}` (Eğer resim sadece barkod, imei etiketi veya bilgi yazısı ise).
5. Çıktıyı SADECE ve SADECE saf JSON formatında ver. Markdown, code block veya başka bir metin EKLEME.

İstenen JSON Yapısı:
{
  "urunler": [
    {
      "ad": "Ürün Adı",
      "kod": "Ürün Kodu (Varsa)",
      "barkod": "Barkod No (Varsa)",
      "birim": "Adet/Kg/Metre (En uygun olan)",
      "alisFiyati": 0.00,
      "satisFiyati1": 0.00,
      "satisFiyati2": 0.00,
      "satisFiyati3": 0.00,
      "kdvOrani": 20.0,
      "stok": 1.0,
      "grubu": "Ürün Grubu/Kategorisi",
      "ozellikler": "Genel notlar",
      "renk": "Ürün Rengi (Varsa)",
      "kapasite": "Hafıza/Kapasite (Varsa, Örn: 256GB)",
      "durum": "Sıfır" veya "İkinci El" (Resimden anlaşılıyorsa, varsayılan: Sıfır),
      "garantiBitis": "YYYY-MM-DD" (Varsa),
      "imeiList": ["IMEI1 - IMEI2", ...],
      "resimler": [
        {"index": 0, "tip": "urun"},
        {"index": 1, "tip": "etiket"}
      ],
      "analizNotu": "Yapay zekanın bu ürün hakkında eklemek istediği kısa not"
    }
  ]
}

ÖNEMLİ: 
- Dual-SIM / Çift IMEI Mantığı: Eğer bir cihazın hem IMEI 1 hem de IMEI 2 numarası varsa, bunları "IMEI1 - IMEI2" şeklinde birleştirerek `imeiList` içine TEK BİR string olarak ekle.
- Seri No ve Diğer Detaylar: Cihazın Seri Numarasını (Serial No / SN) ve resimde gördüğün diğer tüm teknik kodları (Model, FCC ID, Model No vb.) mutlaka `ozellikler` (Notlar) kısmına detaylıca yaz. Seri No'yu oradan silme!
- IMEI ve Seri No Önceliği (imeiList için): Eğer cihazda IMEI varsa, o IMEI'yi (çiftse birleştirerek) `imeiList`'e ekle. Eğer IMEI yoksa o zaman Seri No'yu `imeiList`'e ekle. Ama her iki durumda da Seri No ve tüm detaylar `ozellikler` alanında mutlaka yazılı olmalı.
- Stok Miktarı: `imeiList` içindeki her bir eleman 1 adet fiziksel ürünü temsil eder. `stok` miktarı, `imeiList` uzunluğuna eşit olmalıdır.
- `ad` alanı her ürün için zorunludur. Sayısal alanlar num tipinde olmalıdır.
''';

    final List<Map<String, dynamic>> parts = [
      {"text": prompt},
    ];

    for (final imageBytes in images) {
      parts.add({
        "inline_data": {
          "mime_type": "image/jpeg",
          "data": base64Encode(imageBytes),
        },
      });
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {"parts": parts},
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topP": 1,
          "maxOutputTokens": 4096,
          "response_mime_type": "application/json",
        },
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final String text =
          decoded['candidates'][0]['content']['parts'][0]['text'];

      return Map<String, dynamic>.from(jsonDecode(text));
    }

    throw Exception('AI ürün analizi başarısız oldu: ${response.body}');
  }
}
