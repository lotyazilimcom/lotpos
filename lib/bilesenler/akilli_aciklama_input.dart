import 'package:flutter/material.dart';
import 'package:patisyov10/servisler/ayarlar_veritabani_servisi.dart';
import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';
import 'package:patisyov10/bilesenler/onay_dialog.dart';
import 'dart:async';

/// Akıllı Açıklama / Select Input Bileşeni
///
/// Hem metin girişi yapılabilen hem de listeden seçim yapılabilen hibrit bileşen.
/// - Otomatik tamamlama
/// - Yeni kayıt ekleme (yazıldığında otomatik)
/// - Kayıt silme (çöp kutusu ikonu)
/// - Performanslı arama
class AkilliAciklamaInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String
  category; // DB'de hangi kategoride saklanacağı (örn: 'satis_aciklama')
  final List<String> defaultItems; // Varsayılan (lokalizasyondan gelen) öğeler
  final Function(String)? onChanged;
  final FocusNode? focusNode;
  final Color? color;
  final int? maxLines;
  final int? minLines;
  final bool isDense;
  final bool enabled;

  const AkilliAciklamaInput({
    super.key,
    required this.controller,
    required this.label,
    required this.category,
    this.defaultItems = const [],
    this.onChanged,
    this.focusNode,
    this.color,
    this.maxLines = 1,
    this.minLines,
    this.isDense = false,
    this.enabled = true,
  });

  @override
  State<AkilliAciklamaInput> createState() => _AkilliAciklamaInputState();
}

class _AkilliAciklamaInputState extends State<AkilliAciklamaInput> {
  final _service = AyarlarVeritabaniServisi();
  Timer? _debounce;
  List<String> _suggestions = [];
  final LayerLink _layerLink = LayerLink();
  FocusNode? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(covariant AkilliAciklamaInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode == null && _internalFocusNode == null) {
      _internalFocusNode = FocusNode();
    } else if (widget.focusNode != null && _internalFocusNode != null) {
      _internalFocusNode!.dispose();
      _internalFocusNode = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions([String query = '']) async {
    // DB'den gelenler (aciklamalariGetir zaten hidden olanları filtreliyor mu?
    // Hayır, servis tarafında sadece saved_descriptions'dan gizlileri çıkarıyor.
    // Ancak defaults için de kontrol etmeliyiz.)

    // DB'deki gizli kayıtları al (defaults filtrelemek için)
    final hiddenItems = await _service.gizliAciklamalariGetir(widget.category);

    // DB'den gelen öneriler (Servis zaten gizlileri filtreliyor, ama biz yine de emin olalım)
    final dbItems = await _service.aciklamalariGetir(
      widget.category,
      query: query,
    );

    // Varsayılanlar (Lokalizasyon) - Gizli olanları çıkar
    final defaults = widget.defaultItems.where((item) {
      if (hiddenItems.contains(item)) return false; // Gizliyse gösterme
      if (query.isEmpty) return true;
      return item.toLowerCase().contains(query.toLowerCase());
    }).toList();

    // Birleştir ve Tekilleştir
    final finalSuggestions = <String>[];
    for (var item in dbItems) {
      if (!finalSuggestions.contains(item)) finalSuggestions.add(item);
    }
    for (var item in defaults) {
      if (!finalSuggestions.contains(item)) finalSuggestions.add(item);
    }

    if (mounted) {
      setState(() {
        _suggestions = finalSuggestions;
      });
    }
  }

  Future<void> _deleteItem(String content) async {
    // Onay iste
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.delete'),
        mesaj: '${tr('common.delete_confirmation')}\n\n$content',
        onOnay: () {}, // Dialog kapanınca null/true döneceği için burada boş
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (confirmed != true) return;

    // Sadece DB'den siler. Varsayılanlar silinmez (ama silme başarılı gibi gösterilir)
    await _service.aciklamaSil(widget.category, content);

    // Listeyi güncelle
    await _loadSuggestions(widget.controller.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr("common.deleted")}: $content'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _saveItem(String content) async {
    if (content.trim().isEmpty) return;
    // Otomatik kaydet
    await _service.aciklamaEkle(widget.category, content);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFocusNode = widget.focusNode ?? _internalFocusNode!;
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return CompositedTransformTarget(
          link: _layerLink,
          child: RawAutocomplete<String>(
            textEditingController: widget.controller,
            focusNode: effectiveFocusNode,

            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (_debounce?.isActive ?? false) _debounce!.cancel();

              final query = textEditingValue.text;
              await _loadSuggestions(query);
              return _suggestions;
            },

            onSelected: (String selection) {
              widget.controller.text = selection;
              _saveItem(selection);
              if (widget.onChanged != null) widget.onChanged!(selection);
            },

            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: widget.enabled ? effectiveColor : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: widget.isDense ? 2 : 4),
                      TextFormField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: tr('common.search'),
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.withValues(alpha: 0.3),
                            fontSize: 16,
                          ),
                          suffixIcon: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Icon(
                              Icons.arrow_drop_down,
                              color: effectiveColor,
                            ),
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: effectiveColor.withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: effectiveColor.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: effectiveColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: widget.isDense ? 4 : 10,
                          ),
                        ),
                        enabled: widget.enabled,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 17,
                          color: widget.enabled ? null : Colors.grey.shade400,
                        ),
                        maxLines: widget.maxLines,
                        minLines: widget.minLines,
                        onChanged: (val) {
                          if (widget.onChanged != null) widget.onChanged!(val);
                        },
                        onFieldSubmitted: (val) {
                          _saveItem(val);
                          onFieldSubmitted();
                        },
                      ),
                    ],
                  );
                },

            optionsViewBuilder: (context, onSelected, options) {
              const Color primaryColor = Color(0xFF2C3E50);
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  color: Colors.white,
                  child: Container(
                    width: constraints.maxWidth,
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            onTap: () => onSelected(option),
                            hoverColor: primaryColor.withValues(alpha: 0.08),
                            splashColor: primaryColor.withValues(alpha: 0.12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: index < options.length - 1
                                    ? Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF202124),
                                      ),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: tr('common.delete'),
                                      hoverColor: Colors.red.withValues(
                                        alpha: 0.1,
                                      ),
                                      onPressed: () {
                                        _deleteItem(option);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
