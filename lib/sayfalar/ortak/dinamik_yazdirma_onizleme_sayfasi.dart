import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../yardimcilar/yazdirma/dinamik_yazdirma_servisi.dart';
import '../ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';

class DinamikYazdirmaOnizlemeSayfasi extends StatefulWidget {
  final YazdirmaSablonuModel sablon;
  final Map<String, dynamic> veri;

  const DinamikYazdirmaOnizlemeSayfasi({
    super.key,
    required this.sablon,
    required this.veri,
  });

  @override
  State<DinamikYazdirmaOnizlemeSayfasi> createState() =>
      _DinamikYazdirmaOnizlemeSayfasiState();
}

class _DinamikYazdirmaOnizlemeSayfasiState
    extends State<DinamikYazdirmaOnizlemeSayfasi> {
  // Printer & Destination
  Printer? _selectedPrinter;
  List<Printer> _printers = [];

  // Preview State
  Uint8List? _pdfBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPrinters();
    _generatePdf();
  }

  Future<void> _fetchPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
          if (_printers.isNotEmpty) {
            _selectedPrinter = _printers.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching printers: $e');
    }
  }

  Future<void> _generatePdf() async {
    debugPrint('--- [DinamikYazdirmaOnizlemeSayfasi] _generatePdf STARTED ---');
    setState(() => _isLoading = true);

    try {
      // DinamikYazdirmaServisi already contains the logic to build the document
      // based on the template (page size, margins, content).
      final doc = await DinamikYazdirmaServisi().pdfOlustur(
        sablon: widget.sablon,
        veri: widget.veri,
      );

      // Save the document to bytes
      final bytes = await doc.save();

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating PDF preview: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'print.preview.error.generate_failed',
              ).replaceAll('{error}', e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveAsPdf() async {
    if (_pdfBytes == null) return;

    final String fileName = '${widget.sablon.name}_Çıktı.pdf';
    final prefs = await SharedPreferences.getInstance();
    final String? lastPath = prefs.getString('last_export_path');

    final FileSaveLocation? result = await getSaveLocation(
      suggestedName: fileName,
      initialDirectory: lastPath,
      acceptedTypeGroups: [
        XTypeGroup(
          label: tr('common.pdf'),
          extensions: ['pdf'],
          uniformTypeIdentifiers: ['com.adobe.pdf'],
        ),
      ],
    );

    if (result == null) return;

    final String path = result.path;
    final File file = File(path);
    await file.writeAsBytes(_pdfBytes!);

    final String parentDir = file.parent.path;
    await prefs.setString('last_export_path', parentDir);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'common.success.export_path',
            ).replaceAll('{name}', fileName).replaceAll('{path}', path),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF323639),
      body: Row(
        children: [
          // Left Side: Preview
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_pdfBytes != null)
                  Container(
                    color: const Color(0xFF323639),
                    child: PdfPreview(
                      build: (format) => _pdfBytes!,
                      useActions: false,
                      padding: const EdgeInsets.all(20),
                      pdfPreviewPageDecoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      allowPrinting: false,
                      allowSharing: false,
                      onError: (context, error) =>
                          Center(child: Text(tr('common.error'))),
                    ),
                  ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          // Right Side: Sidebar
          Container(
            width: 350,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('common.print'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Settings List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Destination
                      _buildDropdownRow<Printer?>(
                        label: tr('print.destination'),
                        value: _selectedPrinter,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(tr('print.destination.pdf')),
                              ],
                            ),
                          ),
                          ..._printers.map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.print,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPrinter = val);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Info Text (Template properties are read-only here)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF2C3E50,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr('print.preview.template_info'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2C3E50),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(
                                'print.preview.template',
                              ).replaceAll('{name}', widget.sablon.name),
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              tr('print.preview.paper').replaceAll(
                                '{paper}',
                                widget.sablon.paperSize ?? '',
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              tr('print.preview.orientation').replaceAll(
                                '{orientation}',
                                widget.sablon.isLandscape
                                    ? tr('print.layout.landscape')
                                    : tr('print.layout.portrait'),
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer Buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2C3E50),
                          side: const BorderSide(color: Color(0xFF2C3E50)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(tr('common.cancel')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _pdfBytes == null
                            ? null
                            : () async {
                                if (_selectedPrinter == null) {
                                  await _saveAsPdf();
                                } else {
                                  await Printing.directPrintPdf(
                                    printer: _selectedPrinter!,
                                    onLayout: (format) => _pdfBytes!,
                                    name: '${widget.sablon.name}_Çıktı',
                                  );
                                }
                              },
                        icon: const Icon(Icons.print),
                        label: Text(tr('common.print')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<T>(
                mouseCursor: WidgetStateMouseCursor.clickable,
                dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                value: value,
                isExpanded: true,
                items: items,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
