import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lisans_servisi.dart';

class LosPayYetersizHatasi implements Exception {
  final double gerekliKredi;
  final double mevcutKredi;

  const LosPayYetersizHatasi({
    required this.gerekliKredi,
    required this.mevcutKredi,
  });

  @override
  String toString() =>
      'LosPayYetersizHatasi(gerekli: $gerekliKredi, mevcut: $mevcutKredi)';
}

class LosYapayZekaYapilandirmaHatasi implements Exception {
  final String messageKey;

  const LosYapayZekaYapilandirmaHatasi(this.messageKey);

  @override
  String toString() => messageKey;
}

enum _AiProvider { gemini, openai, anthropic, deepseek, qwen }

class _AiGorselGirdi {
  final Uint8List bytes;
  final String mimeType;

  const _AiGorselGirdi({required this.bytes, required this.mimeType});
}

class _AiIstekBaglami {
  final String apiKey;
  final String model;
  final _AiProvider provider;
  final bool useLosAi;
  final String? customerId;
  final double mevcutKredi;
  final double krediMaliyeti;

  const _AiIstekBaglami({
    required this.apiKey,
    required this.model,
    required this.provider,
    required this.useLosAi,
    required this.customerId,
    required this.mevcutKredi,
    required this.krediMaliyeti,
  });
}

class YapayZekaServisi {
  static final YapayZekaServisi _instance = YapayZekaServisi._internal();
  factory YapayZekaServisi() => _instance;
  YapayZekaServisi._internal();

  static const String _apiKeyKey = 'ai_api_key';
  static const String _modelKey = 'ai_model';
  static const String _modelsKey = 'ai_models_list';
  static const String _providerKey = 'ai_provider';
  static const String _useLosAiKey = 'ai_use_los_ai';
  static const double _losAiCreditCost = 1.0;
  static const Duration _remoteTimeout = Duration(seconds: 4);

  static double get losYapayZekaKrediMaliyeti => _losAiCreditCost;

  Future<void> ayarlariKaydet({
    required String apiKey,
    required String model,
    String provider = 'gemini',
    List<String>? models,
    bool useLosAi = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    await prefs.setString(_modelKey, model);
    await prefs.setString(_providerKey, provider);
    await prefs.setBool(_useLosAiKey, useLosAi);
    if (models != null) {
      await prefs.setStringList(_modelsKey, models);
    }
  }

  Future<Map<String, dynamic>> ayarlariGetir() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    final model = prefs.getString(_modelKey);
    final models = prefs.getStringList(_modelsKey);
    final provider = prefs.getString(_providerKey) ?? 'gemini';
    final useLosAi = prefs.getBool(_useLosAiKey) ?? false;
    return {
      'apiKey': apiKey,
      'model': model,
      'models': models,
      'provider': provider,
      'useLosAi': useLosAi,
    };
  }

  Future<String?> apiAnahtariGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  Future<String?> modelGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey);
  }

  Future<String?> saglayiciGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey);
  }

  Future<bool> losYapayZekaKullanimiAktifMi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useLosAiKey) ?? false;
  }

  bool _isMissingColumnError(PostgrestException error, String columnName) {
    final message = error.message.toLowerCase();
    return message.contains(columnName.toLowerCase()) &&
        (message.contains('column') || message.contains('schema'));
  }

  String? _asCleanString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  _AiProvider _parseProvider(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'openai':
        return _AiProvider.openai;
      case 'anthropic':
        return _AiProvider.anthropic;
      case 'deepseek':
        return _AiProvider.deepseek;
      case 'qwen':
        return _AiProvider.qwen;
      case 'gemini':
      default:
        return _AiProvider.gemini;
    }
  }

  String _defaultModelForProvider(_AiProvider provider) {
    switch (provider) {
      case _AiProvider.gemini:
        return 'gemini-2.5-flash';
      case _AiProvider.openai:
        return 'gpt-4.1-mini';
      case _AiProvider.anthropic:
        return 'claude-sonnet-4-20250514';
      case _AiProvider.deepseek:
        return 'deepseek-chat';
      case _AiProvider.qwen:
        return 'qwen-vl-plus';
    }
  }

  String _openAiCompatibleBaseUrl(_AiProvider provider) {
    switch (provider) {
      case _AiProvider.openai:
        return 'https://api.openai.com/v1';
      case _AiProvider.deepseek:
        return 'https://api.deepseek.com/v1';
      case _AiProvider.qwen:
        return 'https://dashscope.aliyuncs.com/compatible-mode/v1';
      case _AiProvider.gemini:
      case _AiProvider.anthropic:
        return '';
    }
  }

  bool _supportsVision(_AiIstekBaglami baglam) {
    switch (baglam.provider) {
      case _AiProvider.gemini:
      case _AiProvider.openai:
      case _AiProvider.anthropic:
        return true;
      case _AiProvider.deepseek:
        return false;
      case _AiProvider.qwen:
        final model = baglam.model.toLowerCase();
        return model.contains('vl') ||
            model.contains('vision') ||
            model.contains('qvq');
    }
  }

  void _ensureVisionSupported(_AiIstekBaglami baglam) {
    if (_supportsVision(baglam)) return;

    throw const LosYapayZekaYapilandirmaHatasi(
      'settings.ai.los_ai.vision_not_supported',
    );
  }

  String _decodeGeminiText(dynamic decoded) {
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('AI yanıt döndürmedi.');
    }

    final candidate = candidates.first;
    final content = candidate['content'];
    final parts = content is Map<String, dynamic> ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw Exception('AI içerik döndürmedi.');
    }

    final text = parts.first['text']?.toString();
    if (text == null || text.trim().isEmpty) {
      throw Exception('AI içerik döndürmedi.');
    }
    return text.trim();
  }

  String _decodeOpenAiText(dynamic decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('AI yanıt döndürmedi.');
    }

    final message = choices.first['message'];
    final content = message is Map<String, dynamic> ? message['content'] : null;
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        final text = part is Map<String, dynamic>
            ? part['text']?.toString()
            : null;
        if (text != null && text.trim().isNotEmpty) {
          if (buffer.length > 0) buffer.writeln();
          buffer.write(text.trim());
        }
      }
      if (buffer.length > 0) return buffer.toString();
    }

    throw Exception('AI içerik döndürmedi.');
  }

  String _decodeAnthropicText(dynamic decoded) {
    final content = decoded['content'];
    if (content is! List || content.isEmpty) {
      throw Exception('AI yanıt döndürmedi.');
    }

    final buffer = StringBuffer();
    for (final block in content) {
      if (block is! Map<String, dynamic>) continue;
      if (block['type']?.toString() != 'text') continue;
      final text = block['text']?.toString();
      if (text == null || text.trim().isEmpty) continue;
      if (buffer.length > 0) buffer.writeln();
      buffer.write(text.trim());
    }

    if (buffer.length == 0) {
      throw Exception('AI içerik döndürmedi.');
    }

    return buffer.toString();
  }

  Future<_AiIstekBaglami> _aiIstekBaglamiHazirla({
    required String defaultModel,
  }) async {
    final settings = await ayarlariGetir();
    final useLosAi = settings['useLosAi'] == true;

    if (!useLosAi) {
      final apiKey = await apiAnahtariGetir();
      if (apiKey == null || apiKey.trim().isEmpty) {
        throw Exception('AI API anahtarı ayarlanmamış.');
      }

      final provider = _parseProvider(await saglayiciGetir());
      final selectedModel = _asCleanString(settings['model']);

      return _AiIstekBaglami(
        apiKey: apiKey.trim(),
        model:
            selectedModel ??
            (provider == _AiProvider.gemini
                ? defaultModel
                : _defaultModelForProvider(provider)),
        provider: provider,
        useLosAi: false,
        customerId: null,
        mevcutKredi: 0,
        krediMaliyeti: 0,
      );
    }

    return _losAiBaglamiHazirla();
  }

  Future<_AiIstekBaglami> _losAiBaglamiHazirla() async {
    await LisansServisi().baslat();
    final hardwareId = LisansServisi().hardwareId?.trim();

    if (hardwareId == null || hardwareId.isEmpty) {
      throw const LosYapayZekaYapilandirmaHatasi(
        'settings.ai.los_ai.config_missing',
      );
    }

    final supabase = Supabase.instance.client;
    String? customerId;

    try {
      final licenseData = await supabase
          .from('licenses')
          .select('customer_id')
          .eq('hardware_id', hardwareId)
          .order('end_date', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(_remoteTimeout);

      if (licenseData is Map<String, dynamic>) {
        customerId = _asCleanString(licenseData['customer_id']);
      }
    } on PostgrestException catch (e) {
      debugPrint('Yapay Zeka Servisi: Lisans müşteri eşlemesi alınamadı: $e');
      if (_isMissingColumnError(e, 'customer_id')) {
        throw const LosYapayZekaYapilandirmaHatasi(
          'settings.ai.los_ai.config_missing',
        );
      }
    } catch (e) {
      debugPrint('Yapay Zeka Servisi: Lisans müşteri eşlemesi alınamadı: $e');
    }

    Map<String, dynamic>? customerData;
    var useProviderFallback = false;
    var useModelFallback = false;
    try {
      if (customerId != null) {
        final data = await supabase
            .from('customers')
            .select(
              'id, lospay_credit, los_ai_api_key, los_ai_provider, los_ai_model',
            )
            .eq('id', customerId)
            .maybeSingle()
            .timeout(_remoteTimeout);
        if (data is Map<String, dynamic>) {
          customerData = data;
        }
      } else {
        final data = await supabase
            .from('customers')
            .select(
              'id, lospay_credit, los_ai_api_key, los_ai_provider, los_ai_model',
            )
            .eq('hardware_id', hardwareId)
            .maybeSingle()
            .timeout(_remoteTimeout);
        if (data is Map<String, dynamic>) {
          customerData = data;
        }
      }
    } on PostgrestException catch (e) {
      final missingLosPay = _isMissingColumnError(e, 'lospay_credit');
      final missingLosAiKey = _isMissingColumnError(e, 'los_ai_api_key');
      useProviderFallback = _isMissingColumnError(e, 'los_ai_provider');
      useModelFallback = _isMissingColumnError(e, 'los_ai_model');
      if (missingLosPay || missingLosAiKey) {
        throw const LosYapayZekaYapilandirmaHatasi(
          'settings.ai.los_ai.config_missing',
        );
      }

      if (!(useProviderFallback || useModelFallback)) {
        rethrow;
      }

      try {
        final baseSelect = [
          'id',
          'lospay_credit',
          'los_ai_api_key',
          if (!useProviderFallback) 'los_ai_provider',
          if (!useModelFallback) 'los_ai_model',
        ].join(', ');
        final data = await supabase
            .from('customers')
            .select(baseSelect)
            .eq(
              customerId != null ? 'id' : 'hardware_id',
              customerId ?? hardwareId,
            )
            .maybeSingle()
            .timeout(_remoteTimeout);
        if (data is Map<String, dynamic>) {
          customerData = data;
        }
      } on PostgrestException catch (fallbackError) {
        final missingLosPayFallback = _isMissingColumnError(
          fallbackError,
          'lospay_credit',
        );
        final missingLosAiKeyFallback = _isMissingColumnError(
          fallbackError,
          'los_ai_api_key',
        );
        if (missingLosPayFallback || missingLosAiKeyFallback) {
          throw const LosYapayZekaYapilandirmaHatasi(
            'settings.ai.los_ai.config_missing',
          );
        }
        rethrow;
      }
    }

    if (customerData == null) {
      throw const LosYapayZekaYapilandirmaHatasi(
        'settings.ai.los_ai.config_missing',
      );
    }

    final resolvedCustomerId =
        _asCleanString(customerData['id']) ?? customerId ?? '';
    final apiKey = _asCleanString(customerData['los_ai_api_key']);
    final mevcutKredi = _toDouble(customerData['lospay_credit']);
    final provider = useProviderFallback
        ? _AiProvider.gemini
        : _parseProvider(_asCleanString(customerData['los_ai_provider']));
    final model = useModelFallback
        ? _defaultModelForProvider(provider)
        : (_asCleanString(customerData['los_ai_model']) ??
              _defaultModelForProvider(provider));

    if (apiKey == null || apiKey.isEmpty) {
      throw const LosYapayZekaYapilandirmaHatasi(
        'settings.ai.los_ai.config_missing',
      );
    }

    if (mevcutKredi + 0.0001 < _losAiCreditCost) {
      throw LosPayYetersizHatasi(
        gerekliKredi: _losAiCreditCost,
        mevcutKredi: mevcutKredi,
      );
    }

    return _AiIstekBaglami(
      apiKey: apiKey,
      model: model,
      provider: provider,
      useLosAi: true,
      customerId: resolvedCustomerId,
      mevcutKredi: mevcutKredi,
      krediMaliyeti: _losAiCreditCost,
    );
  }

  Future<String> _gorselJsonCevabiUret({
    required _AiIstekBaglami baglam,
    required String prompt,
    required List<_AiGorselGirdi> images,
    required int maxTokens,
  }) async {
    _ensureVisionSupported(baglam);

    late final http.Response response;
    late final String parsedText;

    switch (baglam.provider) {
      case _AiProvider.gemini:
        response = await _callGemini(
          baglam: baglam,
          prompt: prompt,
          images: images,
          maxTokens: maxTokens,
        );
        break;
      case _AiProvider.openai:
      case _AiProvider.deepseek:
      case _AiProvider.qwen:
        response = await _callOpenAiCompatible(
          baglam: baglam,
          prompt: prompt,
          images: images,
          maxTokens: maxTokens,
        );
        break;
      case _AiProvider.anthropic:
        response = await _callAnthropic(
          baglam: baglam,
          prompt: prompt,
          images: images,
          maxTokens: maxTokens,
        );
        break;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _losPayKrediDusIfNeeded(baglam);
      final decoded = jsonDecode(response.body);
      switch (baglam.provider) {
        case _AiProvider.gemini:
          parsedText = _decodeGeminiText(decoded);
          break;
        case _AiProvider.openai:
        case _AiProvider.deepseek:
        case _AiProvider.qwen:
          parsedText = _decodeOpenAiText(decoded);
          break;
        case _AiProvider.anthropic:
          parsedText = _decodeAnthropicText(decoded);
          break;
      }
      return parsedText;
    }

    throw Exception(
      'AI analizi başarısız oldu (${response.statusCode}): ${response.body}',
    );
  }

  Future<http.Response> _callGemini({
    required _AiIstekBaglami baglam,
    required String prompt,
    required List<_AiGorselGirdi> images,
    required int maxTokens,
  }) {
    return http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${baglam.model}:generateContent?key=${baglam.apiKey}',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              ...images.map(
                (image) => {
                  'inline_data': {
                    'mime_type': image.mimeType,
                    'data': base64Encode(image.bytes),
                  },
                },
              ),
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topK': 32,
          'topP': 1,
          'maxOutputTokens': maxTokens,
          'response_mime_type': 'application/json',
        },
      }),
    );
  }

  Future<http.Response> _callOpenAiCompatible({
    required _AiIstekBaglami baglam,
    required String prompt,
    required List<_AiGorselGirdi> images,
    required int maxTokens,
  }) {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      ...images.map(
        (image) => {
          'type': 'image_url',
          'image_url': {
            'url': 'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
          },
        },
      ),
    ];

    return http.post(
      Uri.parse(
        '${_openAiCompatibleBaseUrl(baglam.provider)}/chat/completions',
      ),
      headers: {
        'Authorization': 'Bearer ${baglam.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': baglam.model,
        'messages': [
          {'role': 'user', 'content': content},
        ],
        'temperature': 0.1,
        'max_tokens': maxTokens,
        if (baglam.provider == _AiProvider.openai ||
            baglam.provider == _AiProvider.deepseek)
          'response_format': {'type': 'json_object'},
      }),
    );
  }

  Future<http.Response> _callAnthropic({
    required _AiIstekBaglami baglam,
    required String prompt,
    required List<_AiGorselGirdi> images,
    required int maxTokens,
  }) {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      ...images.map(
        (image) => {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': image.mimeType,
            'data': base64Encode(image.bytes),
          },
        },
      ),
    ];

    return http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': baglam.apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': baglam.model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );
  }

  Future<void> _losPayKrediDusIfNeeded(_AiIstekBaglami baglam) async {
    if (!baglam.useLosAi) return;

    final customerId = baglam.customerId;
    if (customerId == null || customerId.trim().isEmpty) {
      throw const LosYapayZekaYapilandirmaHatasi(
        'settings.ai.los_ai.config_missing',
      );
    }

    final supabase = Supabase.instance.client;
    final hedefBakiye = (baglam.mevcutKredi - baglam.krediMaliyeti)
        .clamp(0, double.infinity)
        .toDouble();

    try {
      final updateResult = await supabase
          .from('customers')
          .update({'lospay_credit': hedefBakiye})
          .eq('id', customerId)
          .gte('lospay_credit', baglam.krediMaliyeti)
          .select('lospay_credit')
          .maybeSingle()
          .timeout(_remoteTimeout);

      if (updateResult is Map<String, dynamic>) {
        await LisansServisi().losPayBakiyesiGuncelle(
          _toDouble(updateResult['lospay_credit']),
        );
        return;
      }

      final latest = await supabase
          .from('customers')
          .select('lospay_credit')
          .eq('id', customerId)
          .maybeSingle()
          .timeout(_remoteTimeout);

      final mevcut = latest is Map<String, dynamic>
          ? _toDouble(latest['lospay_credit'])
          : 0.0;

      await LisansServisi().losPayBakiyesiGuncelle(mevcut);
      throw LosPayYetersizHatasi(
        gerekliKredi: baglam.krediMaliyeti,
        mevcutKredi: mevcut,
      );
    } on PostgrestException catch (e) {
      if (_isMissingColumnError(e, 'lospay_credit')) {
        throw const LosYapayZekaYapilandirmaHatasi(
          'settings.ai.los_ai.config_missing',
        );
      }
      rethrow;
    }
  }

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
      case 'Thermal80Cutter':
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
    final baglam = await _aiIstekBaglamiHazirla(
      defaultModel: 'gemini-2.5-flash-lite',
    );

    Map<String, double> dimensions;
    if (paperSize == 'Custom' && customWidth != null && customHeight != null) {
      dimensions = {'width': customWidth, 'height': customHeight};
    } else {
      dimensions = _getPaperDimensions(paperSize);
    }

    final pageWidth = isLandscape
        ? dimensions['height']!
        : dimensions['width']!;
    final pageHeight = isLandscape
        ? dimensions['width']!
        : dimensions['height']!;

    final fieldsList = availableFields
        .map((e) => '${e['key']}: ${e['label']}')
        .join(', ');

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

    final text = await _gorselJsonCevabiUret(
      baglam: baglam,
      prompt: prompt,
      images: [_AiGorselGirdi(bytes: imageBytes, mimeType: 'image/png')],
      maxTokens: 4096,
    );

    try {
      final parsed = jsonDecode(text);
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
    } catch (_) {}

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
      } catch (_) {}
    }

    throw Exception('AI geçersiz JSON döndürdü: $text');
  }

  Future<Map<String, dynamic>> analizEtGiderFisi(Uint8List imageBytes) async {
    final baglam = await _aiIstekBaglamiHazirla(
      defaultModel: 'gemini-1.5-flash',
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

    final text = await _gorselJsonCevabiUret(
      baglam: baglam,
      prompt: prompt,
      images: [_AiGorselGirdi(bytes: imageBytes, mimeType: 'image/jpeg')],
      maxTokens: 4096,
    );

    return Map<String, dynamic>.from(jsonDecode(text));
  }

  Future<Map<String, dynamic>> analizEtHizliUrun(List<Uint8List> images) async {
    final baglam = await _aiIstekBaglamiHazirla(
      defaultModel: 'gemini-1.5-flash',
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

    final text = await _gorselJsonCevabiUret(
      baglam: baglam,
      prompt: prompt,
      images: images
          .map((bytes) => _AiGorselGirdi(bytes: bytes, mimeType: 'image/jpeg'))
          .toList(),
      maxTokens: 4096,
    );

    return Map<String, dynamic>.from(jsonDecode(text));
  }
}
