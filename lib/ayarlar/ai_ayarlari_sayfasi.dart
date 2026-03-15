import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../bilesenler/standart_alt_aksiyon_bar.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../servisler/yapay_zeka_servisi.dart';

class AiAyarlariSayfasi extends StatefulWidget {
  const AiAyarlariSayfasi({super.key});

  @override
  State<AiAyarlariSayfasi> createState() => _AiAyarlariSayfasiState();
}

class _AiAyarlariSayfasiState extends State<AiAyarlariSayfasi> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyController;
  String _selectedProvider = 'gemini';
  String _savedProvider = 'gemini';
  String _selectedModel = 'gemini-2.5-flash';
  String _savedApiKey = '';
  String _savedModel = 'gemini-2.5-flash';
  bool _useLosAi = false;
  bool _savedUseLosAi = false;
  List<String> _savedModels = ['gemini-2.5-flash', 'gemini-2.5-flash-lite'];
  bool _isLoading = false;
  bool _isTesting = false;

  List<String> _availableModels = ['gemini-2.5-flash', 'gemini-2.5-flash-lite'];

  static const List<String> _providerOrder = [
    'gemini',
    'openai',
    'anthropic',
    'deepseek',
    'qwen',
  ];

  String _normalizedProvider(String? provider) {
    final value = (provider ?? '').trim().toLowerCase();
    return _providerOrder.contains(value) ? value : 'gemini';
  }

  List<String> _defaultModelsForProvider(String provider) {
    switch (provider) {
      case 'openai':
        return ['gpt-4.1-mini', 'gpt-4.1', 'gpt-4o', 'gpt-4o-mini'];
      case 'anthropic':
        return [
          'claude-3-7-sonnet-latest',
          'claude-3-5-sonnet-latest',
          'claude-3-5-haiku-latest',
        ];
      case 'deepseek':
        return ['deepseek-chat', 'deepseek-reasoner'];
      case 'qwen':
        return ['qwen-vl-plus', 'qwen2.5-vl-72b-instruct', 'qvq-plus'];
      case 'gemini':
      default:
        return ['gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-2.5-pro'];
    }
  }

  String _defaultModelForProvider(String provider) {
    return _defaultModelsForProvider(provider).first;
  }

  List<String> _normalizedModels(
    List<String> source, {
    required String provider,
    String? selectedModel,
  }) {
    final fallback = _defaultModelsForProvider(provider);
    final seen = <String>{};
    final normalized = <String>[];
    for (final model in source) {
      final trimmed = model.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      normalized.add(trimmed);
    }

    final selected = selectedModel?.trim();
    if (selected != null && selected.isNotEmpty && seen.add(selected)) {
      normalized.add(selected);
    }

    if (normalized.isEmpty) {
      return List<String>.from(fallback);
    }

    return normalized;
  }

  String _providerLabel(String provider) {
    return tr('settings.ai.local.provider.$provider');
  }

  Uri _openAiCompatibleModelsUri(String provider) {
    switch (provider) {
      case 'openai':
        return Uri.parse('https://api.openai.com/v1/models');
      case 'deepseek':
        return Uri.parse('https://api.deepseek.com/v1/models');
      case 'qwen':
        return Uri.parse(
          'https://dashscope.aliyuncs.com/compatible-mode/v1/models',
        );
      case 'gemini':
      case 'anthropic':
      default:
        throw UnsupportedError('Unsupported provider: $provider');
    }
  }

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await YapayZekaServisi().ayarlariGetir();
      final String apiKey = (settings['apiKey'] ?? '').toString();
      final String provider = _normalizedProvider(
        settings['provider']?.toString(),
      );
      final String rawModel = (settings['model'] ?? '').toString().trim();
      final String selectedModel = rawModel.isEmpty
          ? _defaultModelForProvider(provider)
          : rawModel;

      final List<String> defaultModels = _defaultModelsForProvider(provider);
      final List<String> loadedModels = settings['models'] != null
          ? List<String>.from(settings['models'])
          : defaultModels;
      final List<String> finalModels = _normalizedModels(
        loadedModels,
        provider: provider,
        selectedModel: selectedModel,
      );

      if (mounted) {
        setState(() {
          _savedApiKey = apiKey;
          _savedProvider = provider;
          _savedModel = selectedModel;
          _savedUseLosAi = settings['useLosAi'] == true;
          _savedModels = List<String>.from(finalModels);

          _apiKeyController.text = _savedApiKey;
          _selectedProvider = _savedProvider;
          _selectedModel = _savedModel;
          _useLosAi = _savedUseLosAi;
          _availableModels = List<String>.from(_savedModels);
        });
      }
    } catch (e) {
      debugPrint('Error loading AI settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('validation.required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final loadedModels = await _fetchProviderModels(
        provider: _selectedProvider,
        apiKey: apiKey,
      );

      final normalized = _normalizedModels(
        loadedModels,
        provider: _selectedProvider,
      );

      setState(() {
        _availableModels = normalized;
        if (!_availableModels.contains(_selectedModel)) {
          _selectedModel = _availableModels.first;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.ai.test_api_success')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('settings.ai.test_api_error')}$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<List<String>> _fetchProviderModels({
    required String provider,
    required String apiKey,
  }) async {
    switch (provider) {
      case 'gemini':
        return _fetchGeminiModels(apiKey);
      case 'openai':
      case 'deepseek':
      case 'qwen':
        return _fetchOpenAiCompatibleModels(provider: provider, apiKey: apiKey);
      case 'anthropic':
        return _fetchAnthropicModels(apiKey);
      default:
        return _defaultModelsForProvider(provider);
    }
  }

  Future<List<String>> _fetchGeminiModels(String apiKey) async {
    final response = await http.get(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load models. Status Code: ${response.statusCode}',
      );
    }

    final data = json.decode(response.body);
    final List<dynamic> models = data['models'] ?? [];
    final availableModels = <String>[];

    for (final model in models) {
      final name = model['name']?.toString() ?? '';
      final methods =
          model['supportedGenerationMethods'] as List<dynamic>? ?? [];

      if (methods.contains('generateContent') &&
          name.toLowerCase().contains('gemini')) {
        availableModels.add(name.replaceFirst('models/', ''));
      }
    }

    if (availableModels.isEmpty) {
      throw Exception('No compatible Gemini models found.');
    }

    return availableModels;
  }

  Future<List<String>> _fetchAnthropicModels(String apiKey) async {
    final response = await http.get(
      Uri.parse('https://api.anthropic.com/v1/models'),
      headers: {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load models. Status Code: ${response.statusCode}',
      );
    }

    final data = json.decode(response.body);
    final List<dynamic> models = data['data'] ?? [];
    final availableModels = models
        .map((item) => item is Map<String, dynamic> ? item['id'] : null)
        .whereType<String>()
        .where((id) => id.toLowerCase().contains('claude'))
        .toList();

    if (availableModels.isEmpty) {
      throw Exception('No compatible Claude models found.');
    }

    return availableModels;
  }

  Future<List<String>> _fetchOpenAiCompatibleModels({
    required String provider,
    required String apiKey,
  }) async {
    final response = await http.get(
      _openAiCompatibleModelsUri(provider),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load models. Status Code: ${response.statusCode}',
      );
    }

    final data = json.decode(response.body);
    final List<dynamic> models = data['data'] ?? [];
    final availableModels = models
        .map((item) => item is Map<String, dynamic> ? item['id'] : null)
        .whereType<String>()
        .where((id) => _isCompatibleModel(id, provider))
        .toList();

    if (availableModels.isEmpty) {
      throw Exception('No compatible models found.');
    }

    return availableModels;
  }

  bool _isCompatibleModel(String modelId, String provider) {
    final id = modelId.toLowerCase();
    switch (provider) {
      case 'openai':
        if (id.contains('embed') ||
            id.contains('image') ||
            id.contains('audio') ||
            id.contains('moderation') ||
            id.contains('transcribe') ||
            id.contains('tts') ||
            id.contains('realtime')) {
          return false;
        }
        return id.startsWith('gpt') ||
            id.startsWith('o1') ||
            id.startsWith('o3') ||
            id.startsWith('o4');
      case 'deepseek':
        return id.contains('deepseek');
      case 'qwen':
        return id.contains('qwen') || id.contains('qvq') || id.contains('vl');
      case 'gemini':
      case 'anthropic':
      default:
        return true;
    }
  }

  void _onProviderChanged(String provider) {
    final models = _defaultModelsForProvider(provider);
    setState(() {
      _selectedProvider = provider;
      _availableModels = List<String>.from(models);
      _selectedModel = _defaultModelForProvider(provider);
    });
  }

  Future<void> _kaydet() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await YapayZekaServisi().ayarlariKaydet(
          apiKey: _apiKeyController.text.trim(),
          provider: _selectedProvider,
          model: _selectedModel,
          models: _availableModels,
          useLosAi: _useLosAi,
        );

        _savedApiKey = _apiKeyController.text.trim();
        _savedProvider = _selectedProvider;
        _savedModel = _selectedModel;
        _savedUseLosAi = _useLosAi;
        _savedModels = List<String>.from(_availableModels);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('settings.ai.save_success')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${tr('common.error')}: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _iptalEt() {
    if (_isLoading) return;
    setState(() {
      _apiKeyController.text = _savedApiKey;
      _selectedProvider = _savedProvider;
      _selectedModel = _savedModel;
      _useLosAi = _savedUseLosAi;
      _availableModels = List<String>.from(_savedModels);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _kaydet,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _kaydet,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 800;
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 20 : 40),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('settings.ai.title'),
                                style: TextStyle(
                                  fontSize: isMobile ? 24 : 28,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF202124),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr('settings.ai.subtitle'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF5F6368),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 36),
                              _buildLosAiUsageCard(),
                              const SizedBox(height: 36),
                              _buildSectionTitle(tr('settings.ai.local.title')),
                              const SizedBox(height: 24),
                              _buildLocalAiInputs(constraints.maxWidth),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildBottomActionBar(isCompact: isMobile),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar({required bool isCompact}) {
    return StandartAltAksiyonBar(
      isCompact: isCompact,
      secondaryText: tr('common.cancel'),
      onSecondaryPressed: _isLoading ? null : _iptalEt,
      primaryText: tr('common.save'),
      onPrimaryPressed: _kaydet,
      primaryLoading: _isLoading,
      alignment: Alignment.centerRight,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: Color(0xFF2C3E50),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalAiInputs(double maxWidth) {
    final providerDropdown = _buildProviderDropdown(enabled: !_useLosAi);
    final apiKeyField = _buildApiKeyField(enabled: !_useLosAi);
    final modelDropdown = _buildUnderlinedDropdown(
      label: tr('settings.ai.local.model'),
      value: _selectedModel,
      items: _availableModels,
      onChanged: !_useLosAi
          ? (val) => setState(() => _selectedModel = val!)
          : null,
      icon: Icons.model_training_rounded,
      enabled: !_useLosAi,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_useLosAi)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6EEF5)),
            ),
            child: Text(
              tr(
                'settings.ai.los_ai.config_note',
                args: {
                  'credit': YapayZekaServisi.losYapayZekaKrediMaliyeti
                      .toStringAsFixed(0),
                },
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ),
        if (maxWidth > 900)
          SizedBox(width: maxWidth > 1240 ? 360 : 320, child: providerDropdown)
        else
          providerDropdown,
        const SizedBox(height: 24),
        if (maxWidth > 800)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: apiKeyField),
              const SizedBox(width: 32),
              Expanded(flex: 1, child: modelDropdown),
            ],
          )
        else
          Column(
            children: [apiKeyField, const SizedBox(height: 32), modelDropdown],
          ),
      ],
    );
  }

  Widget _buildProviderDropdown({required bool enabled}) {
    return _buildUnderlinedDropdown(
      label: tr('settings.ai.local.provider'),
      value: _selectedProvider,
      items: _providerOrder,
      onChanged: enabled ? (val) => _onProviderChanged(val!) : null,
      icon: Icons.hub_rounded,
      enabled: enabled,
      itemLabelBuilder: _providerLabel,
    );
  }

  Widget _buildLosAiUsageCard() {
    final highlightColor = const Color(0xFFF59E0B);
    final borderColor = highlightColor.withValues(alpha: 0.24);
    final background = const LinearGradient(
      colors: [Color(0xFFFFFAF3), Color(0xFFFFF4E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: highlightColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: highlightColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('settings.ai.los_ai.title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('settings.ai.los_ai.subtitle'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5F6368),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Switch.adaptive(
                  value: _useLosAi,
                  activeTrackColor: highlightColor.withValues(alpha: 0.45),
                  activeThumbColor: highlightColor,
                  onChanged: (value) => setState(() => _useLosAi = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildLosAiBadge(
                icon: Icons.wallet_giftcard_rounded,
                text: tr('settings.ai.los_ai.credit_required'),
              ),
              _buildLosAiBadge(
                icon: Icons.local_fire_department_rounded,
                text: tr(
                  'settings.ai.los_ai.cost_badge',
                  args: {
                    'credit': YapayZekaServisi.losYapayZekaKrediMaliyeti
                        .toStringAsFixed(0),
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              'settings.ai.los_ai.help',
              args: {
                'credit': YapayZekaServisi.losYapayZekaKrediMaliyeti
                    .toStringAsFixed(0),
              },
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLosAiBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF6D9B3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B4F15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyField({required bool enabled}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUnderlinedField(
          label: tr('settings.ai.local.api_key'),
          hint: tr(
            'settings.ai.local.api_key_hint',
            args: {'provider': _providerLabel(_selectedProvider)},
          ),
          controller: _apiKeyController,
          icon: Icons.vpn_key_rounded,
          obscureText: true,
          isRequired: enabled,
          enabled: enabled,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: enabled
              ? TextButton.icon(
                  onPressed: _isTesting ? null : _fetchModels,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(tr('settings.ai.test_api')),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2C3E50),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              : Text(
                  tr('settings.ai.los_ai.api_source_hint'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9AA0A6),
                    height: 1.45,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUnderlinedField({
    required String label,
    String? hint,
    required TextEditingController controller,
    IconData? icon,
    bool obscureText = false,
    bool isRequired = false,
    bool enabled = true,
  }) {
    final labelColor = const Color(0xFF5F6368);
    final borderColor = const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: enabled ? labelColor : const Color(0xFF9AA0A6),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          cursorColor: enabled ? const Color(0xFF2C3E50) : Colors.transparent,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, size: 22, color: const Color(0xFFBDC1C6))
                : null,
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFFBDC1C6),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            disabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE8EAED)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnderlinedDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    IconData? icon,
    bool enabled = true,
    String Function(String item)? itemLabelBuilder,
  }) {
    // Seçili değer listede yoksa ilkini seç (fallback)
    final effectiveValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: enabled ? const Color(0xFF5F6368) : const Color(0xFF9AA0A6),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          mouseCursor: enabled
              ? WidgetStateMouseCursor.clickable
              : SystemMouseCursors.forbidden,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          // 'value' FormField içinde deprecated olduğu için 'initialValue' kullanıyoruz.
          // Ancak FormField state'i kendi değerini yönetir. DropdownButtonFormField hem 'value' hem form state kullanınca karışabiliyor.
          // En temiz çözüm: key vererek widget'i yeniden oluşturmak veya sadece initialValue kullanmak.
          // Burada basitçe value -> initialValue yaparsak form resetlenince sorun olabilir.
          // Fakat deprecation warning'e göre 'initialValue' kullanmalıyız.
          key: ValueKey('ai_model_${effectiveValue}_${items.length}'),
          initialValue: effectiveValue,
          onChanged: enabled ? onChanged : null,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFBDC1C6)),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF202124) : const Color(0xFF9AA0A6),
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, size: 22, color: const Color(0xFFBDC1C6))
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: enabled
                    ? const Color(0xFFE0E0E0)
                    : const Color(0xFFE8EAED),
              ),
            ),
            disabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE8EAED)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(itemLabelBuilder?.call(item) ?? item),
            );
          }).toList(),
        ),
      ],
    );
  }
}
