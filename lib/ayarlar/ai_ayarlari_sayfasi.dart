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
  String _selectedModel = 'gemini-pro';
  String _savedApiKey = '';
  String _savedModel = 'gemini-pro';
  List<String> _savedModels = [
    'gemini-pro',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];
  bool _isLoading = false;
  bool _isTesting = false;

  List<String> _geminiModels = [
    'gemini-pro',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

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
      final String rawModel = (settings['model'] ?? '').toString().trim();
      final String selectedModel = rawModel.isEmpty ? 'gemini-pro' : rawModel;

      final List<String> defaultModels = [
        'gemini-pro',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
      ];
      final List<String> loadedModels = settings['models'] != null
          ? List<String>.from(settings['models'])
          : defaultModels;

      final Set<String> seen = <String>{};
      final List<String> normalizedModels = <String>[];
      for (final m in loadedModels) {
        final trimmed = m.toString().trim();
        if (trimmed.isEmpty) continue;
        if (seen.add(trimmed)) normalizedModels.add(trimmed);
      }
      if (!seen.contains(selectedModel)) normalizedModels.add(selectedModel);

      final List<String> finalModels = normalizedModels.isNotEmpty
          ? normalizedModels
          : defaultModels;

      if (mounted) {
        setState(() {
          _savedApiKey = apiKey;
          _savedModel = selectedModel;
          _savedModels = List<String>.from(finalModels);

          _apiKeyController.text = _savedApiKey;
          _selectedModel = _savedModel;
          _geminiModels = List<String>.from(_savedModels);
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
      final response = await http.get(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> models = data['models'] ?? [];
        final List<String> availableModels = [];

        for (var model in models) {
          final name = model['name']?.toString() ?? '';
          final List<dynamic> methods =
              model['supportedGenerationMethods'] ?? [];

          // Sadece 'generateContent' metodunu destekleyen ve 'gemini' içeren modelleri al
          if (methods.contains('generateContent') &&
              name.toLowerCase().contains('gemini')) {
            // "models/" ön ekini kaldır
            final cleanName = name.replaceFirst('models/', '');
            availableModels.add(cleanName);
          }
        }

        if (availableModels.isNotEmpty) {
          setState(() {
            _geminiModels = availableModels;
            if (!_geminiModels.contains(_selectedModel)) {
              _selectedModel = _geminiModels.first;
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
        } else {
          throw Exception('No compatible Gemini models found.');
        }
      } else {
        throw Exception(
          'Failed to load models. Status Code: ${response.statusCode}',
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

  Future<void> _kaydet() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await YapayZekaServisi().ayarlariKaydet(
          apiKey: _apiKeyController.text.trim(),
          model: _selectedModel,
          models: _geminiModels,
        );

        _savedApiKey = _apiKeyController.text.trim();
        _savedModel = _selectedModel;
        _savedModels = List<String>.from(_geminiModels);

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
      _selectedModel = _savedModel;
      _geminiModels = List<String>.from(_savedModels);
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
                              _buildSectionTitle(
                                tr('settings.ai.gemini.title'),
                              ),
                              const SizedBox(height: 24),
                              _buildGeminiInputs(constraints.maxWidth),
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

  Widget _buildGeminiInputs(double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxWidth > 800)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildApiKeyField()),
              const SizedBox(width: 32),
              Expanded(
                flex: 1,
                child: _buildUnderlinedDropdown(
                  label: tr('settings.ai.gemini.model'),
                  value: _selectedModel,
                  items: _geminiModels,
                  onChanged: (val) => setState(() => _selectedModel = val!),
                  icon: Icons.model_training_rounded,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildApiKeyField(),
              const SizedBox(height: 32),
              _buildUnderlinedDropdown(
                label: tr('settings.ai.gemini.model'),
                value: _selectedModel,
                items: _geminiModels,
                onChanged: (val) => setState(() => _selectedModel = val!),
                icon: Icons.model_training_rounded,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    // API Key alanı ve Test Butonu
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUnderlinedField(
          label: tr('settings.ai.gemini.api_key'),
          hint: tr('settings.ai.gemini.api_key_hint'),
          controller: _apiKeyController,
          icon: Icons.vpn_key_rounded,
          obscureText: true,
          isRequired: true,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
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
                color: labelColor,
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
          cursorColor: const Color(0xFF2C3E50),
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
    required ValueChanged<String?> onChanged,
    IconData? icon,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          // 'value' FormField içinde deprecated olduğu için 'initialValue' kullanıyoruz.
          // Ancak FormField state'i kendi değerini yönetir. DropdownButtonFormField hem 'value' hem form state kullanınca karışabiliyor.
          // En temiz çözüm: key vererek widget'i yeniden oluşturmak veya sadece initialValue kullanmak.
          // Burada basitçe value -> initialValue yaparsak form resetlenince sorun olabilir.
          // Fakat deprecation warning'e göre 'initialValue' kullanmalıyız.
          key: ValueKey('ai_model_${effectiveValue}_${items.length}'),
          initialValue: effectiveValue,
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFBDC1C6)),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, size: 22, color: const Color(0xFFBDC1C6))
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
        ),
      ],
    );
  }
}
