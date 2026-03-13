import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';

class PerakendeYazdirmaAyarlariDialogResult {
  final int? sablonId;
  final String? yaziciJson;
  final int kopyaSayisi;

  const PerakendeYazdirmaAyarlariDialogResult({
    required this.sablonId,
    required this.yaziciJson,
    required this.kopyaSayisi,
  });
}

class PerakendeYazdirmaAyarlariDialog extends StatefulWidget {
  final List<YazdirmaSablonuModel> sablonlar;
  final int? seciliSablonId;
  final String? seciliYaziciJson;
  final int kopyaSayisi;
  final Future<List<Printer>> Function() yazicilariYukle;

  const PerakendeYazdirmaAyarlariDialog({
    super.key,
    required this.sablonlar,
    required this.seciliSablonId,
    required this.seciliYaziciJson,
    required this.kopyaSayisi,
    required this.yazicilariYukle,
  });

  @override
  State<PerakendeYazdirmaAyarlariDialog> createState() =>
      _PerakendeYazdirmaAyarlariDialogState();
}

class _PerakendeYazdirmaAyarlariDialogState
    extends State<PerakendeYazdirmaAyarlariDialog> {
  static const String _missingPrinterValue = '__saved_missing__';

  late int? _seciliSablonId;
  late final TextEditingController _kopyaSayisiController;

  List<Printer> _printers = const [];
  bool _printersLoading = true;
  String? _printerError;
  String _seciliYaziciDegeri = '';
  String? _kayitliEksikYaziciJson;
  String? _kayitliEksikYaziciEtiketi;
  String? _kopyaHatasi;

  @override
  void initState() {
    super.initState();
    _seciliSablonId =
        widget.seciliSablonId ??
        (widget.sablonlar.isNotEmpty ? widget.sablonlar.first.id : null);
    _kopyaSayisiController = TextEditingController(
      text: widget.kopyaSayisi.toString(),
    );
    _yazicilariYenile();
  }

  @override
  void dispose() {
    _kopyaSayisiController.dispose();
    super.dispose();
  }

  Future<void> _yazicilariYenile() async {
    if (!mounted) return;
    setState(() {
      _printersLoading = true;
      _printerError = null;
    });

    try {
      final printers = await widget.yazicilariYukle();
      if (!mounted) return;

      final normalized = printers.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final savedPrinter = _decodePrinter(widget.seciliYaziciJson);
      final matchedPrinter = savedPrinter == null
          ? null
          : _findMatchingPrinter(normalized, savedPrinter);

      setState(() {
        _printers = normalized;
        _printersLoading = false;
        _kayitliEksikYaziciJson = null;
        _kayitliEksikYaziciEtiketi = null;

        if (matchedPrinter != null) {
          _seciliYaziciDegeri = _printerIdentity(matchedPrinter);
        } else if (savedPrinter != null) {
          _seciliYaziciDegeri = _missingPrinterValue;
          _kayitliEksikYaziciJson = widget.seciliYaziciJson;
          _kayitliEksikYaziciEtiketi = _printerDisplayName(savedPrinter);
        } else {
          _seciliYaziciDegeri = '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printers = const [];
        _printersLoading = false;
        _printerError = e.toString();
      });
    }
  }

  Printer? _decodePrinter(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Printer.fromMap(decoded.cast<String, dynamic>());
      }
    } catch (_) {}

    return Printer(url: value, name: value);
  }

  String _printerIdentity(Printer printer) {
    final url = printer.url.trim();
    if (url.isNotEmpty) return url;
    return printer.name.trim();
  }

  Printer? _findMatchingPrinter(List<Printer> printers, Printer candidate) {
    final candidateIdentity = _printerIdentity(candidate);
    for (final printer in printers) {
      if (_printerIdentity(printer) == candidateIdentity) {
        return printer;
      }
      if (printer.name.trim() == candidate.name.trim()) {
        return printer;
      }
    }
    return null;
  }

  String _printerDisplayName(Printer printer) {
    final isDefault = printer.isDefault ? ' (${tr('common.default')})' : '';
    if (printer.name.trim().isNotEmpty) {
      return '${printer.name}$isDefault';
    }
    return '${_printerIdentity(printer)}$isDefault';
  }

  String? _seciliYaziciJsonDegeri() {
    if (_seciliYaziciDegeri.isEmpty) return null;
    if (_seciliYaziciDegeri == _missingPrinterValue) {
      return _kayitliEksikYaziciJson;
    }

    for (final printer in _printers) {
      if (_printerIdentity(printer) == _seciliYaziciDegeri) {
        return jsonEncode(printer.toMap());
      }
    }
    return null;
  }

  YazdirmaSablonuModel? _selectedTemplate() {
    for (final sablon in widget.sablonlar) {
      if (sablon.id == _seciliSablonId) return sablon;
    }
    return widget.sablonlar.isEmpty ? null : widget.sablonlar.first;
  }

  void _kaydet() {
    final kopyaSayisi =
        int.tryParse(_kopyaSayisiController.text.trim()) ?? 0;
    if (kopyaSayisi < 1) {
      setState(() => _kopyaHatasi = tr('retail.print_settings.copy_count_error'));
      return;
    }

    final sablon = _selectedTemplate();
    Navigator.of(context).pop(
      PerakendeYazdirmaAyarlariDialogResult(
        sablonId: sablon?.id,
        yaziciJson: _seciliYaziciJsonDegeri(),
        kopyaSayisi: kopyaSayisi,
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String description,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF606368),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing case final Widget item) item,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText, String? errorText}) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEA4335)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEA4335), width: 1.5),
      ),
    );
  }

  List<DropdownMenuItem<String>> _printerItems() {
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: '',
        child: Text(tr('common.none')),
      ),
    ];

    if (_kayitliEksikYaziciJson != null && _kayitliEksikYaziciEtiketi != null) {
      items.add(
        DropdownMenuItem<String>(
          value: _missingPrinterValue,
          child: Text(_kayitliEksikYaziciEtiketi!),
        ),
      );
    }

    items.addAll(
      _printers.map(
        (printer) => DropdownMenuItem<String>(
          value: _printerIdentity(printer),
          child: Text(
            _printerDisplayName(printer),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    return items;
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isCompact = screenSize.width < 760;
    final double maxDialogWidth = isCompact ? screenSize.width - 24 : 760;
    final double maxDialogHeight = screenSize.height * 0.9;
    final sablon = _selectedTemplate();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.enter): _kaydet,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _kaydet,
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dialogRadius),
          ),
          child: Container(
            width: maxDialogWidth,
            constraints: BoxConstraints(maxHeight: maxDialogHeight),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dialogRadius),
            ),
            padding: EdgeInsets.fromLTRB(
              isCompact ? 18 : 28,
              isCompact ? 18 : 24,
              isCompact ? 18 : 28,
              isCompact ? 16 : 22,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('settings.cashPrint.printGroup.title'),
                              style: TextStyle(
                                fontSize: isCompact ? 19 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF202124),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('settings.cashPrint.printGroup.description'),
                              style: TextStyle(
                                fontSize: isCompact ? 13 : 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF606368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isCompact)
                            Text(
                              tr('common.esc'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9AA0A6),
                              ),
                            ),
                          if (!isCompact) const SizedBox(width: 8),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: tr('common.close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sablon?.name ?? tr('print_after_sale.select_template'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sablon == null
                                    ? tr('print_after_sale.error.no_template_selected')
                                    : '${tr('settings.print.types.${sablon.effectiveDocType}')} • ${sablon.paperSize ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF606368),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool stack = constraints.maxWidth < 620;
                      final templateCard = _buildSettingCard(
                        icon: Icons.description_rounded,
                        accentColor: const Color(0xFF1E88E5),
                        title: tr('settings.cashPrint.print.mode.label'),
                        description: tr('settings.cashPrint.print.mode.help'),
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey<String>(
                            'template-${_seciliSablonId ?? 'none'}-${widget.sablonlar.length}',
                          ),
                          initialValue: widget.sablonlar.any(
                            (template) => template.id == _seciliSablonId,
                          )
                              ? _seciliSablonId
                              : null,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          decoration: _inputDecoration(
                            hintText: tr('print_after_sale.select_template'),
                          ),
                          items: widget.sablonlar
                              .map(
                                (template) => DropdownMenuItem<int?>(
                                  value: template.id,
                                  child: Text(
                                    template.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: widget.sablonlar.isEmpty
                              ? null
                              : (value) {
                                  setState(() => _seciliSablonId = value);
                                },
                        ),
                      );

                      final printerCard = _buildSettingCard(
                        icon: Icons.print_rounded,
                        accentColor: const Color(0xFF14B8A6),
                        title: tr('settings.printer.default.label'),
                        description: tr('settings.cashPrint.print.printer.help'),
                        trailing: IconButton(
                          onPressed: _printersLoading ? null : _yazicilariYenile,
                          tooltip: tr('settings.connection.printer.refresh'),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              key: ValueKey<String>(
                                'printer-$_seciliYaziciDegeri-${_printers.length}-${_kayitliEksikYaziciEtiketi ?? 'none'}',
                              ),
                              initialValue: _printerItems()
                                      .any(
                                        (item) =>
                                            item.value == _seciliYaziciDegeri,
                                      )
                                  ? _seciliYaziciDegeri
                                  : '',
                              isExpanded: true,
                              menuMaxHeight: 320,
                              decoration: _inputDecoration(
                                hintText: tr(
                                  'settings.connection.printer.dropdown.label',
                                ),
                              ),
                              items: _printerItems(),
                              onChanged: (_printersLoading || _printerError != null)
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _seciliYaziciDegeri = value ?? '';
                                      });
                                    },
                            ),
                            if (_printersLoading) ...[
                              const SizedBox(height: 10),
                              Text(
                                tr('settings.connection.printer.loading'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF606368),
                                ),
                              ),
                            ],
                            if (_printerError != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                tr('settings.connection.printer.error'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEA4335),
                                ),
                              ),
                            ] else if (_kayitliEksikYaziciJson != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                tr('settings.connection.printer.missing'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF39C12),
                                ),
                              ),
                            ] else if (!_printersLoading && _printers.isEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                tr('settings.connection.printer.empty'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF606368),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );

                      if (stack) {
                        return Column(
                          children: [
                            templateCard,
                            const SizedBox(height: 14),
                            printerCard,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: templateCard),
                          const SizedBox(width: 14),
                          Expanded(child: printerCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildSettingCard(
                    icon: Icons.copy_all_rounded,
                    accentColor: const Color(0xFF2C3E50),
                    title: tr('settings.cashPrint.print.copyCount.label'),
                    description: tr('settings.cashPrint.print.copyCount.help'),
                    child: SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _kopyaSayisiController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: _inputDecoration(errorText: _kopyaHatasi),
                        onChanged: (_) {
                          if (_kopyaHatasi != null) {
                            setState(() => _kopyaHatasi = null);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool stackButtons = constraints.maxWidth < 460;
                      final cancelButton = TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF5F6368),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          tr('common.cancel'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );

                      final saveButton = ElevatedButton.icon(
                        onPressed: widget.sablonlar.isEmpty ? null : _kaydet,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          tr('common.apply'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                      );

                      if (stackButtons) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            cancelButton,
                            const SizedBox(height: 8),
                            saveButton,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          cancelButton,
                          const SizedBox(width: 12),
                          saveButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
