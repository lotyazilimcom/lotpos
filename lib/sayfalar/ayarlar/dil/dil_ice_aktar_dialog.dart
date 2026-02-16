import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';

class DilIceAktarDialog extends StatefulWidget {
  const DilIceAktarDialog({super.key});

  @override
  State<DilIceAktarDialog> createState() => _DilIceAktarDialogState();
}

class _DilIceAktarDialogState extends State<DilIceAktarDialog> {
  static const Color _primaryColor = Color(0xFF2C3E50);
  final TextEditingController _jsonController = TextEditingController();

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _downloadSampleJson() async {
    final ceviriServisi = CeviriServisi();
    final translations = ceviriServisi.getCeviriler('en');

    if (translations == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('common.error.noData'))));
      }
      return;
    }

    // Construct JSON
    final Map<String, dynamic> jsonContent = {
      "language": {
        "name": "English",
        "short_form": "en",
        "language_code": "en-US",
        "text_direction": "ltr",
        "text_editor_lang": "en",
      },
      "translations": translations.entries
          .map((e) => {"label": e.key, "translation": e.value})
          .toList(),
    };

    final String jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonContent);
    const String fileName = 'en.json';

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastPath = prefs.getString('last_export_path');

      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: fileName,
        initialDirectory: lastPath,
        acceptedTypeGroups: [
          XTypeGroup(
            label: tr('common.json'),
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );

      if (result == null) {
        return;
      }

      final String path = result.path;
      final File file = File(path);
      await file.writeAsString(jsonString);

      final String parentDir = file.parent.path;
      await prefs.setString('last_export_path', parentDir);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('common.success.generic')} $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('common.error.generic')}$e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastPath = prefs.getString('last_import_path');

      final XTypeGroup typeGroup = XTypeGroup(
        label: tr('common.json'),
        extensions: ['json'],
        uniformTypeIdentifiers: ['public.json'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
        initialDirectory: lastPath,
      );

      if (file == null) {
        return;
      }

      final String content = await file.readAsString();

      // Save directory
      final String path = file.path;
      final File f = File(path);
      final String parentDir = f.parent.path;
      await prefs.setString('last_import_path', parentDir);

      setState(() {
        _jsonController.text = content;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('common.error.fileRead')}$e')),
        );
      }
    }
  }

  void _importLanguage() {
    final String content = _jsonController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('validation.required'))));
      return;
    }

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(content);

      // Validate structure
      if (!jsonMap.containsKey('language') ||
          !jsonMap.containsKey('translations')) {
        throw FormatException(tr('validation.invalid_format'));
      }

      final language = jsonMap['language'];
      final String name = language['name'] ?? 'Bilinmeyen';
      final String code = language['short_form'] ?? 'unknown';
      final String directionStr = language['text_direction'] ?? 'ltr';

      final TextDirection direction = directionStr == 'rtl'
          ? TextDirection.rtl
          : TextDirection.ltr;

      final List<dynamic> translationsList = jsonMap['translations'];
      final Map<String, String> translationsMap = {};

      for (var item in translationsList) {
        if (item is Map &&
            item.containsKey('label') &&
            item.containsKey('translation')) {
          translationsMap[item['label']] = item['translation'];
        }
      }

      // Add to service
      final ceviriServisi = Provider.of<CeviriServisi>(context, listen: false);
      ceviriServisi.yeniDilEkle(code, name, translationsMap, direction);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name ${tr('common.success.added')}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('common.error.generic')}${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const dialogRadius = 14.0;
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final dialogWidth = isMobile ? mediaQuery.size.width * 0.95 : 820.0;
    final maxDialogHeight = isMobile
        ? mediaQuery.size.height * 0.9
        : mediaQuery.size.height * 0.86;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
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
          isMobile ? 18 : 28,
          24,
          isMobile ? 18 : 28,
          22,
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
                          tr('language.dialog.import.title'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('language.dialog.import.subtitle'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF606368),
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
              const SizedBox(height: 18),
              Text(
                tr('language.dialog.import.jsonContent'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A4A4A),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: isMobile ? 230 : 280,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: _jsonController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF202124),
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: tr('language.dialog.import.jsonHint'),
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFBDC1C6),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    prefixIcon: const Icon(
                      Icons.data_object_outlined,
                      size: 20,
                      color: Color(0xFFBDC1C6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(tr('language.dialog.import.selectFile')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A4A4A),
                        side: const BorderSide(color: Color(0xFFBDBDBD)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _downloadSampleJson,
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(tr('language.dialog.import.downloadSample')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A4A4A),
                        side: const BorderSide(color: Color(0xFFBDBDBD)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double maxRowWidth = constraints.maxWidth > 320
                            ? 320
                            : constraints.maxWidth;
                        const double gap = 12;
                        final double buttonWidth = (maxRowWidth - gap) / 2;

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
                                    onPressed: _importLanguage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      tr('common.upload'),
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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  spacing: 12,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: Text(
                              tr('language.dialog.import.selectFile'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A4A4A),
                              side: const BorderSide(color: Color(0xFFBDBDBD)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton.icon(
                            onPressed: _downloadSampleJson,
                            icon: const Icon(Icons.download, size: 18),
                            label: Text(
                              tr('language.dialog.import.downloadSample'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A4A4A),
                              side: const BorderSide(color: Color(0xFFBDBDBD)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                          onPressed: _importLanguage,
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
                            tr('common.upload'),
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
            ],
          ),
        ),
      ),
    );
  }
}
