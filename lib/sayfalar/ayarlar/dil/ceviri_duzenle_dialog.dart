import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';

// Actually, DilModel is in dil_ayarlari.dart. I should probably move DilModel to its own file to be clean,
// but the user said "Refactoring" so maybe I should do that.
// However, to be safe and quick, I will just accept the language name and code as arguments.

class CeviriDuzenleDialog extends StatefulWidget {
  final String languageName;
  final String languageCode;

  const CeviriDuzenleDialog({
    super.key,
    required this.languageName,
    required this.languageCode,
  });

  @override
  State<CeviriDuzenleDialog> createState() => _CeviriDuzenleDialogState();
}

class _CeviriDuzenleDialogState extends State<CeviriDuzenleDialog> {
  static const Color _primaryColor = Color(0xFF2C3E50);

  // Mock data matching the image
  List<Map<String, TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final ceviriServisi = Provider.of<CeviriServisi>(context, listen: false);
    final translations = await ceviriServisi.getCevirilerAsync(
      widget.languageCode,
    );

    if (!mounted) return;

    setState(() {
      if (translations != null) {
        _controllers = translations.entries.map((entry) {
          return {
            'key': TextEditingController(text: entry.key),
            'value': TextEditingController(text: entry.value),
          };
        }).toList();
      } else {
        _controllers = [];
      }
    });
  }

  @override
  void dispose() {
    for (var map in _controllers) {
      map['key']?.dispose();
      map['value']?.dispose();
    }
    super.dispose();
  }

  void _addNewTranslation() {
    setState(() {
      _controllers.add({
        'key': TextEditingController(),
        'value': TextEditingController(),
      });
    });
  }

  void _removeTranslation(int index) {
    setState(() {
      final removed = _controllers.removeAt(index);
      removed['key']?.dispose();
      removed['value']?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    const dialogRadius = 14.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): _saveTranslations,
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            _saveTranslations,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            final isMobile = mediaQuery.size.width < 600;
            final dialogWidth = isMobile ? mediaQuery.size.width * 0.95 : 820.0;
            final maxDialogHeight = isMobile
                ? mediaQuery.size.height * 0.9
                : mediaQuery.size.height * 0.86;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dialogRadius),
              ),
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: maxDialogHeight,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(dialogRadius),
                ),
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 20 : 28,
                  24,
                  isMobile ? 20 : 28,
                  22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('language.dialog.edit.title'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr('language.dialog.edit.subtitle'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF606368),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.languageName} (${widget.languageCode})',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF202124),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!isMobile) ...[
                              Text(
                                tr('common.esc'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9AA0A6),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: const Icon(
                                  Icons.close,
                                  size: 22,
                                  color: Color(0xFF3C4043),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                tooltip: tr('common.close'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Column Headers (Hide on Mobile)
                    if (!isMobile)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                tr('language.dialog.edit.key'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A4A4A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: Text(
                                tr('language.dialog.edit.value'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A4A4A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40), // Space for delete icon
                          ],
                        ),
                      ),

                    // Scrollable List
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _controllers.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final controllers = _controllers[index];
                            if (isMobile) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        tr('language.dialog.edit.key'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4A4A4A),
                                        ),
                                      ),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                          onTap: () =>
                                              _removeTranslation(index),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Color(0xFF5F6368),
                                          ),
                                        )),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  _buildTextField(
                                    controller: controllers['key']!,
                                    hint: tr('language.dialog.edit.key.hint'),
                                    icon: Icons.vpn_key_outlined,
                                    isBold: true,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    tr('language.dialog.edit.value'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4A4A4A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildTextField(
                                    controller: controllers['value']!,
                                    hint: tr('language.dialog.edit.value.hint'),
                                    icon: Icons.translate_outlined,
                                    isBold: true,
                                  ),
                                ],
                              );
                            } else {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildTextField(
                                      controller: controllers['key']!,
                                      hint: tr('language.dialog.edit.key.hint'),
                                      icon: Icons.vpn_key_outlined,
                                      isBold: true,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 6,
                                    child: _buildTextField(
                                      controller: controllers['value']!,
                                      hint: tr(
                                        'language.dialog.edit.value.hint',
                                      ),
                                      icon: Icons.translate_outlined,
                                      isBold:
                                          true, // Based on image, values are also bold/dark
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Color(0xFF5F6368),
                                        ),
                                        onPressed: () =>
                                            _removeTranslation(index),
                                        splashRadius: 20,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bottom Actions
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: TextButton.icon(
                                onPressed: _addNewTranslation,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(tr('language.dialog.edit.add')),
                                style: TextButton.styleFrom(
                                  foregroundColor: _primaryColor,
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double maxRowWidth =
                                  constraints.maxWidth > 320
                                  ? 320
                                  : constraints.maxWidth;
                              const double gap = 12;
                              final double buttonWidth =
                                  (maxRowWidth - gap) / 2;

                              return Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: maxRowWidth,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: buttonWidth,
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          style: TextButton.styleFrom(
                                            foregroundColor: _primaryColor,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                          child: Text(
                                            tr('common.cancel'),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: gap),
                                      SizedBox(
                                        width: buttonWidth,
                                        child: ElevatedButton(
                                          onPressed: _saveTranslations,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            tr('common.save'),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: TextButton.icon(
                              onPressed: _addNewTranslation,
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(tr('language.dialog.edit.add')),
                              style: TextButton.styleFrom(
                                foregroundColor: _primaryColor,
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: _primaryColor,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  tr('common.cancel'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tr('common.esc'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9AA0A6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _saveTranslations,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              tr('common.save'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isBold = false,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        fontSize: 15,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
        color: const Color(0xFF202124),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFFBDC1C6),
        ),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFFBDC1C6)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
        ),
      ),
    );
  }

  void _saveTranslations() {
    final Map<String, String> newTranslations = {};
    for (var controllerMap in _controllers) {
      final key = controllerMap['key']!.text.trim();
      final value = controllerMap['value']!.text.trim();
      if (key.isNotEmpty) {
        newTranslations[key] = value;
      }
    }

    final ceviriServisi = Provider.of<CeviriServisi>(context, listen: false);

    TextDirection direction = TextDirection.ltr;
    if (widget.languageCode == 'ar') {
      direction = TextDirection.rtl;
    }

    ceviriServisi.yeniDilEkle(
      widget.languageCode,
      widget.languageName,
      newTranslations,
      direction,
    );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.languageName} ${tr('language.dialog.edit.success')}',
        ),
      ),
    );
  }
}
