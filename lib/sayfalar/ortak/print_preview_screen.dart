import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../yardimcilar/yazdirma/print_service.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../bilesenler/margin_overlay.dart';
import '../../servisler/lite_kisitlari.dart';
import '../../servisler/lisans_servisi.dart';

class CustomContentToggle {
  final String key;
  final String label;

  const CustomContentToggle({required this.key, required this.label});
}

typedef PdfBytesBuilder =
    Future<Uint8List> Function({
      required PdfPageFormat format,
      required pw.EdgeInsets margins,
      Map<String, bool>? toggles,
    });

class PrintPreviewScreen extends StatefulWidget {
  final String title;
  final List<String> headers;
  final List<List<String>> data;
  final PdfBytesBuilder? pdfBuilder;

  final PdfPageFormat? initialPageFormat;
  final bool? initialLandscape;
  final String? initialMarginType;
  final bool lockPaperSize;
  final bool lockOrientation;
  final bool lockMargins;
  final bool enableExcelExport;

  final bool showHeaderFooterOption;
  final bool showBackgroundGraphicsOption;

  final List<CustomContentToggle>? customToggles;

  const PrintPreviewScreen({
    super.key,
    required this.title,
    required this.headers,
    required this.data,
    this.pdfBuilder,
    this.initialPageFormat,
    this.initialLandscape,
    this.initialMarginType,
    this.lockPaperSize = false,
    this.lockOrientation = false,
    this.lockMargins = false,
    this.enableExcelExport = true,
    this.showHeaderFooterOption = true,
    this.showBackgroundGraphicsOption = true,
    this.customToggles,
  });

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  // Print Settings
  PdfPageFormat _pageFormat = PdfPageFormat.a4;
  bool _isLandscape = false;
  int _copies = 1;
  bool _showHeaders = true;
  bool _showBackground = false;

  // Printer & Destination
  Printer? _selectedPrinter; // null means 'Save as PDF'
  List<Printer> _printers = [];

  // Margins
  String _marginType = 'default'; // default, none, custom
  double _marginTop = 10.0; // mm
  double _marginBottom = 10.0; // mm
  double _marginLeft = 10;
  double _marginRight = 10;
  // [2026 FIX] Performance optimization: Use ValueNotifier to avoid full rebuilds on hover
  final ValueNotifier<bool> _showMarginsNotifier = ValueNotifier(false);

  // Pages
  String _pagesType = 'all'; // all, custom

  // Scale
  String _scaleType = 'default'; // default, custom
  int _scaleValue = 100;

  // Custom Toggles
  final Map<String, bool> _customTogglesState = {};

  // Preview State
  Uint8List? _pdfBytes;
  bool _isLoading = true;

  @override
  void dispose() {
    _showMarginsNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pageFormat = widget.initialPageFormat ?? PdfPageFormat.a4;
    _isLandscape = widget.initialLandscape ?? false;
    _marginType = widget.initialMarginType ?? 'default';

    // Initialize custom toggles
    if (widget.customToggles != null) {
      for (final toggle in widget.customToggles!) {
        _customTogglesState[toggle.key] = true;
      }
    }

    _fetchPrinters();
    _generatePdf();
  }

  Future<void> _fetchPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
          // Select first printer by default if available
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
    setState(() => _isLoading = true);

    final format = _isLandscape ? _pageFormat.landscape : _pageFormat.portrait;

    // Calculate margins
    pw.EdgeInsets margins;
    if (_marginType == 'none') {
      margins = const pw.EdgeInsets.all(0);
    } else if (_marginType == 'custom') {
      margins = pw.EdgeInsets.fromLTRB(
        PdfPageFormat.mm * _marginLeft,
        PdfPageFormat.mm * _marginTop,
        PdfPageFormat.mm * _marginRight,
        PdfPageFormat.mm * _marginBottom,
      );
    } else {
      // Default
      margins = const pw.EdgeInsets.all(40); // approx 14mm
    }

    final Uint8List bytes;
    if (widget.pdfBuilder != null) {
      bytes = await widget.pdfBuilder!(
        format: format,
        margins: margins,
        toggles: _customTogglesState,
      );
    } else {
      bytes = await PrintService.generatePdf(
        format: format,
        title: widget.title,
        headers: widget.headers,
        data: widget.data,
        margin: margins,
      );
    }

    if (mounted) {
      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePrint() async {
    if (_pdfBytes == null) return;

    if (_selectedPrinter == null) {
      // Save as PDF
      await _saveAsPdf();
    } else {
      // Print to selected printer
      await Printing.directPrintPdf(
        printer: _selectedPrinter!,
        onLayout: (format) => _pdfBytes!,
        name: widget.title,
        format: _isLandscape ? _pageFormat.landscape : _pageFormat.portrait,
      );
    }
  }

  Future<void> _saveAsPdf() async {
    if (_pdfBytes == null) return;

    final String fileName = '${widget.title}.pdf';
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
            ).replaceAll('{name}', widget.title).replaceAll('{path}', path),
          ),
        ),
      );
    }
  }

  Future<void> _saveAsExcel() async {
    // Create a new Excel document.
    final xlsio.Workbook workbook = xlsio.Workbook();
    // Accessing via index
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = widget.title.length > 30
        ? widget.title.substring(0, 30)
        : widget.title;

    // Add Title
    sheet.getRangeByName('A1').setText(widget.title);
    sheet.getRangeByName('A1').cellStyle.fontSize = 14;
    sheet.getRangeByName('A1').cellStyle.bold = true;

    // Add Headers
    for (int i = 0; i < widget.headers.length; i++) {
      final cell = sheet.getRangeByIndex(3, i + 1);
      cell.setText(widget.headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#2C3E50'; // Corporate Blue
      cell.cellStyle.fontColor = '#FFFFFF'; // White text
    }

    // Add Data
    for (int i = 0; i < widget.data.length; i++) {
      final row = widget.data[i];
      for (int j = 0; j < row.length; j++) {
        final cell = sheet.getRangeByIndex(i + 4, j + 1);
        cell.setText(row[j]);

        // Zebra striping
        if (i % 2 != 0) {
          cell.cellStyle.backColor = '#F5F5F5';
        }
      }
    }

    // Auto-fit columns
    for (int i = 0; i < widget.headers.length; i++) {
      sheet.autoFitColumn(i + 1);
    }

    // Save
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final String fileName = '${widget.title}.xlsx';
    final prefs = await SharedPreferences.getInstance();
    final String? lastPath = prefs.getString('last_export_path');

    final FileSaveLocation? result = await getSaveLocation(
      suggestedName: fileName,
      initialDirectory: lastPath,
      acceptedTypeGroups: [
        XTypeGroup(
          label: tr('common.excel'),
          extensions: ['xlsx'],
          uniformTypeIdentifiers: [
            'org.openxmlformats.spreadsheetml.sheet',
            'com.microsoft.excel.xlsx',
          ],
        ),
      ],
    );

    if (result == null) return;

    final String path = result.path;
    final File file = File(path);
    await file.writeAsBytes(bytes);

    final String parentDir = file.parent.path;
    await prefs.setString('last_export_path', parentDir);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'common.success.export_path',
            ).replaceAll('{name}', widget.title).replaceAll('{path}', path),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Sidebar width is fixed 350
    final availW = screenW - 350 - 32; // 16 padding each side
    final availH = screenH - 32;

    if (_pdfBytes == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF525659),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF525659),
      body: Row(
        children: [
          // Left Side: Preview Area
          Expanded(
            child: Stack(
              children: [
                if (!_isLoading)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final effectiveFormat = _isLandscape
                          ? _pageFormat.landscape
                          : _pageFormat.portrait;
                      final pageAspectRatio =
                          effectiveFormat.width / effectiveFormat.height;

                      double actualPageW;
                      double actualPageH;

                      if (availW / availH > pageAspectRatio) {
                        actualPageH = availH;
                        actualPageW = actualPageH * pageAspectRatio;
                      } else {
                        actualPageW = availW;
                        actualPageH = actualPageW / pageAspectRatio;
                      }

                      double left = (availW - actualPageW) / 2 + 16;
                      double top = (availH - actualPageH) / 2 + 16;
                      // Center alignment logic check
                      if (left < 16) left = 16;
                      if (top < 16) top = 16;

                      final pageRect = Rect.fromLTWH(
                        left,
                        top,
                        actualPageW,
                        actualPageH,
                      );
                      final referencePageWidthMm =
                          effectiveFormat.width / PdfPageFormat.mm;

                      return MouseRegion(
                        onEnter: (_) => _showMarginsNotifier.value = true,
                        onExit: (_) => _showMarginsNotifier.value = false,
                        child: Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            // 1. PDF Kağıdı (Sabit ve Sarsıntısız)
                            Positioned(
                              left: left,
                              top: top,
                              width: actualPageW,
                              height: actualPageH,
                              child: Container(
                                decoration: const BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: PdfPreview(
                                  build: (format) => _pdfBytes!,
                                  useActions: false,
                                  padding: EdgeInsets.zero,
                                  previewPageMargin: EdgeInsets.zero,
                                  scrollViewDecoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  pdfPreviewPageDecoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  canChangeOrientation: false,
                                  canChangePageFormat: false,
                                  allowPrinting: false,
                                  allowSharing: false,
                                  maxPageWidth: actualPageW,
                                ),
                              ),
                            ),
                            // 2. Margin Overlay (Hover Durumunda Görünür - ValueListenable ile)
                            ValueListenableBuilder<bool>(
                              valueListenable: _showMarginsNotifier,
                              builder: (context, showMargins, child) {
                                return IgnorePointer(
                                  ignoring: !showMargins,
                                  child: Visibility(
                                    visible: showMargins,
                                    child: MarginOverlay(
                                      marginTop: _marginTop,
                                      marginBottom: _marginBottom,
                                      marginLeft: _marginLeft,
                                      marginRight: _marginRight,
                                      pageRect: pageRect,
                                      referencePageWidthMm:
                                          referencePageWidthMm,
                                      onMarginsChanged: (t, b, l, r) {
                                        setState(() {
                                          _marginTop = t;
                                          _marginBottom = b;
                                          _marginLeft = l;
                                          _marginRight = r;
                                          _marginType = 'custom';
                                          // Force update
                                        });
                                        _generatePdf();
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
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
                      const SizedBox(height: 16),

                      // Pages
                      _buildDropdownRow<String>(
                        label: tr('print.pages'),
                        value: _pagesType,
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(tr('print.pages.all')),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text(tr('print.pages.custom')),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _pagesType = val!);
                        },
                      ),
                      if (_pagesType == 'custom') ...[
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: tr('print.pages.hint'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          onChanged: (val) {},
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Copies
                      _buildInputRow(
                        label: tr('print.copies'),
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: TextEditingController(
                              text: _copies.toString(),
                            ),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _copies = int.tryParse(val) ?? 1;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Layout
                      _buildDropdownRow<String>(
                        label: tr('print.layout'),
                        value: _isLandscape ? 'landscape' : 'portrait',
                        items: [
                          DropdownMenuItem(
                            value: 'portrait',
                            child: Text(tr('print.layout.portrait')),
                          ),
                          DropdownMenuItem(
                            value: 'landscape',
                            child: Text(tr('print.layout.landscape')),
                          ),
                        ],
                        onChanged: widget.lockOrientation
                            ? null
                            : (val) {
                                setState(() {
                                  _isLandscape = val == 'landscape';
                                });
                                _generatePdf();
                              },
                      ),
                      const SizedBox(height: 24),

                      // More Settings
                      ExpansionTile(
                        title: Text(
                          tr('print.more_settings'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        initiallyExpanded: true,
                        shape: const Border(),
                        children: [
                          const SizedBox(height: 16),

                          // Paper Size
                          _buildDropdownRow<PdfPageFormat>(
                            label: tr('print.paper_size'),
                            value: _pageFormat,
                            items: [
                              DropdownMenuItem(
                                value: PdfPageFormat.a4,
                                child: Text(tr('print.paper_size.a4')),
                              ),
                              DropdownMenuItem(
                                value: PdfPageFormat.a5,
                                child: Text(tr('print.paper_size.a5')),
                              ),
                              DropdownMenuItem(
                                value: PdfPageFormat.letter,
                                child: Text(tr('print.paper_size.letter')),
                              ),
                            ],
                            onChanged: widget.lockPaperSize
                                ? null
                                : (val) {
                                    setState(() => _pageFormat = val!);
                                    _generatePdf();
                                  },
                          ),
                          const SizedBox(height: 16),

                          // Margins
                          _buildDropdownRow<String>(
                            label: tr('print.margins'),
                            value: _marginType,
                            items: [
                              DropdownMenuItem(
                                value: 'default',
                                child: Text(tr('print.margins.default')),
                              ),
                              DropdownMenuItem(
                                value: 'none',
                                child: Text(tr('print.margins.none')),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text(tr('print.margins.custom')),
                              ),
                            ],
                            onChanged: widget.lockMargins
                                ? null
                                : (val) {
                                    setState(() => _marginType = val!);
                                    _generatePdf();
                                  },
                          ),
                          if (_marginType == 'custom') ...[
                            const SizedBox(height: 8),
                            _buildCustomMargins(),
                          ],
                          const SizedBox(height: 16),

                          // Column Settings Button
                          if (widget.customToggles != null &&
                              widget.customToggles!.isNotEmpty) ...[
                            InkWell(
                              mouseCursor: WidgetStateMouseCursor.clickable,
                              onTap: _showColumnSettingsDialog,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.view_column_outlined,
                                      size: 18,
                                      color: Color(0xFF2C3E50),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr('common.column_settings'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Scale
                          _buildDropdownRow<String>(
                            label: tr('print.scale'),
                            value: _scaleType,
                            items: [
                              DropdownMenuItem(
                                value: 'default',
                                child: Text(tr('print.scale.default')),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text(tr('print.scale.custom')),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _scaleType = val!);
                            },
                          ),
                          if (_scaleType == 'custom') ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 80,
                                  height: 36,
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: _scaleValue.toString(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      suffixText: '%',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _scaleValue = int.tryParse(val) ?? 100;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Options
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  tr('print.options'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    if (widget.showHeaderFooterOption)
                                      _buildCheckbox(
                                        label: tr('print.headers_footers'),
                                        value: _showHeaders,
                                        onChanged: (val) {
                                          setState(() => _showHeaders = val!);
                                        },
                                      ),
                                    if (widget.showBackgroundGraphicsOption)
                                      _buildCheckbox(
                                        label: tr('print.background_graphics'),
                                        value: _showBackground,
                                        onChanged: (val) {
                                          setState(
                                            () => _showBackground = val!,
                                          );
                                        },
                                      ),
                                    const SizedBox(height: 12),
                                    // Save Buttons
                                    OutlinedButton.icon(
                                      onPressed: _saveAsPdf,
                                      icon: const Icon(
                                        Icons.picture_as_pdf,
                                        size: 16,
                                      ),
                                      label: Text(tr('print.save_as_pdf')),
                                      style: OutlinedButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed:
                                          widget.enableExcelExport &&
                                              (!LisansServisi().isLiteMode ||
                                                  LiteKisitlari
                                                      .isExcelExportActive)
                                          ? _saveAsExcel
                                          : null,
                                      icon: const Icon(
                                        Icons.table_view,
                                        size: 16,
                                      ),
                                      label: Text(tr('print.save_as_excel')),
                                      style: OutlinedButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
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
                      FilledButton(
                        onPressed: _handlePrint,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(tr('common.print')),
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

  void _showColumnSettingsDialog() {
    Map<String, bool> localToggles = Map.from(_customTogglesState);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.view_column_outlined,
                    color: Color(0xFF2C3E50),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('common.column_settings'),
                    style: const TextStyle(
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          tr('common.content_settings'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.customToggles!.map((toggle) {
                          return _buildExtraToggleCheckbox(
                            setDialogState,
                            localToggles,
                            toggle,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('common.cancel'),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update state
                    setState(() {
                      _customTogglesState.clear();
                      _customTogglesState.addAll(localToggles);
                    });
                    Navigator.pop(context);
                    _generatePdf();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    tr('common.save'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildExtraToggleCheckbox(
    StateSetter setDialogState,
    Map<String, bool> localMap,
    CustomContentToggle toggle,
  ) {
    return SizedBox(
      width: 170,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          setDialogState(() {
            localMap[toggle.key] = !(localMap[toggle.key] ?? true);
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: localMap[toggle.key] ?? true,
                  activeColor: const Color(0xFF2C3E50),
                  onChanged: (val) {
                    setDialogState(() {
                      localMap[toggle.key] = val ?? true;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toggle.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF455A64),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomMargins() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMarginInput(
                  tr('print.margins.top'),
                  _marginTop,
                  (val) => _marginTop = val,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMarginInput(
                  tr('print.margins.bottom'),
                  _marginBottom,
                  (val) => _marginBottom = val,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMarginInput(
                  tr('print.margins.left'),
                  _marginLeft,
                  (val) => _marginLeft = val,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMarginInput(
                  tr('print.margins.right'),
                  _marginRight,
                  (val) => _marginRight = val,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarginInput(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextField(
            controller: TextEditingController(text: value.toString()),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: tr('common.unit.mm'),
              suffixStyle: const TextStyle(fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: (val) {
              final newValue = double.tryParse(val);
              if (newValue != null) {
                onChanged(newValue);
                _generatePdf(); // Regenerate on change
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                mouseCursor: WidgetStateMouseCursor.clickable,
                dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                value: value,
                items: items,
                onChanged: onChanged,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow({required String label, required Widget child}) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2C3E50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ],
    );
  }
}
