import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_excel_service.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../bilesenler/margin_overlay.dart';
import '../../servisler/lite_kisitlari.dart';
import '../../servisler/lisans_servisi.dart';

class CustomContentToggle {
  final String key;
  final String label;
  final bool defaultValue;

  const CustomContentToggle({
    required this.key,
    required this.label,
    this.defaultValue = true,
  });
}

typedef ProcessDetailCellCallback =
    String Function({
      required String header,
      required String content,
      required Map<String, bool> toggles,
    });

class GenisletilebilirPrintPreviewScreen extends StatefulWidget {
  final String title;
  final List<String> headers;
  final List<ExpandableRowData> data;
  final String? dateInterval;
  final bool initialShowDetails;
  final List<bool>? initialMainColumnVisibility;
  final Map<String, dynamic>? headerInfo;
  final String? mainTableLabel;
  final String? detailTableLabel;
  final List<CustomContentToggle>? extraDetailToggles;
  final List<CustomContentToggle>? headerToggles;
  final ProcessDetailCellCallback? onProcessDetailCell;
  final bool hideFeaturesCheckbox;

  const GenisletilebilirPrintPreviewScreen({
    super.key,
    required this.title,
    required this.headers,
    required this.data,
    this.dateInterval,
    this.initialShowDetails = false,
    this.initialMainColumnVisibility,
    this.headerInfo,
    this.mainTableLabel,
    this.detailTableLabel,
    this.extraDetailToggles,
    this.headerToggles,
    this.onProcessDetailCell,
    this.hideFeaturesCheckbox = false,
  });

  @override
  State<GenisletilebilirPrintPreviewScreen> createState() =>
      _GenisletilebilirPrintPreviewScreenState();
}

class _GenisletilebilirPrintPreviewScreenState
    extends State<GenisletilebilirPrintPreviewScreen> {
  // Print Settings
  PdfPageFormat _pageFormat = PdfPageFormat.a4;
  bool _isLandscape = false;
  int _copies = 1;
  bool _showHeaders = true;
  final bool _showBackground = true;
  late bool _showDetails;

  // Printer & Destination
  Printer? _selectedPrinter; // null means 'Save as PDF'
  List<Printer> _printers = [];

  // Margins
  String _marginType = 'default';
  double _marginTop = 10.0;
  double _marginBottom = 10.0;
  double _marginLeft = 10.0;
  double _marginRight = 10.0;
  final ValueNotifier<bool> _showMarginsNotifier = ValueNotifier(false);

  // Pages
  String _pagesType = 'all';

  // Preview State
  Uint8List? _pdfBytes;
  bool _isLoading = true;

  // Column Visibility State
  late List<bool> _visibleMainIndices;
  late List<bool> _visibleDetailIndices;
  List<String> _detailHeaders = [];

  // Custom Content Toggles State
  final Map<String, bool> _extraTogglesState = {};
  final Map<String, bool> _headerTogglesState = {};

  String _columnsPrefsKey(String scope, List<String> headers) {
    final raw = headers.map((e) => e.trim()).join('\u0001');
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'print_preview_${scope}_columns_$digest';
  }

  @override
  void initState() {
    super.initState();
    _showDetails = widget.initialShowDetails;

    // Initialize Main Column Visibility (default: all true)
    final initialMain = widget.initialMainColumnVisibility;
    if (initialMain != null && initialMain.length == widget.headers.length) {
      _visibleMainIndices = List<bool>.from(initialMain);
    } else {
      _visibleMainIndices = List.filled(widget.headers.length, true);
    }
    if (_visibleMainIndices.isNotEmpty && !_visibleMainIndices.any((v) => v)) {
      _visibleMainIndices[0] = true;
    }

    // Initialize Detail Column Visibility
    // Find first row with transactions to get headers
    for (var row in widget.data) {
      if (row.transactions != null && row.transactions!.headers.isNotEmpty) {
        _detailHeaders = row.transactions!.headers;
        break;
      }
    }
    _visibleDetailIndices = List.filled(_detailHeaders.length, true);

    // Initialize Extra Toggles
    if (widget.extraDetailToggles != null) {
      for (var toggle in widget.extraDetailToggles!) {
        _extraTogglesState[toggle.key] = toggle.defaultValue;
      }
    }

    // Initialize Header Toggles
    if (widget.headerToggles != null) {
      for (var toggle in widget.headerToggles!) {
        _headerTogglesState[toggle.key] = toggle.defaultValue;
      }
    }

    _fetchPrinters();
    _loadColumnSettings(); // Load saved preferences
  }

  Future<void> _loadColumnSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load main column settings
    final initialMain = widget.initialMainColumnVisibility;
    final bool overrideMain =
        initialMain != null && initialMain.length == widget.headers.length;
    if (overrideMain) {
      setState(() {
        _visibleMainIndices = List<bool>.from(initialMain);
      });
    } else {
      final mainKey = _columnsPrefsKey('main', widget.headers);
      final savedMain = prefs.getStringList(mainKey);
      if (savedMain != null && savedMain.length == widget.headers.length) {
        setState(() {
          _visibleMainIndices = savedMain.map((s) => s == 'true').toList();
        });
      }
    }
    // Prevent "all hidden" state which can produce an empty/invalid PDF
    if (_visibleMainIndices.isNotEmpty && !_visibleMainIndices.any((v) => v)) {
      setState(() {
        _visibleMainIndices[0] = true;
      });
    }

    // Load detail column settings
    if (_detailHeaders.isNotEmpty) {
      final detailKey = _columnsPrefsKey('detail', _detailHeaders);
      final savedDetail = prefs.getStringList(detailKey);
      if (savedDetail != null && savedDetail.length == _detailHeaders.length) {
        setState(() {
          _visibleDetailIndices = savedDetail.map((s) => s == 'true').toList();
        });
      }
      // Prevent "all hidden" state for detail table as well
      if (_visibleDetailIndices.isNotEmpty &&
          !_visibleDetailIndices.any((v) => v)) {
        setState(() {
          _visibleDetailIndices[0] = true;
        });
      }
    }

    // Load header toggles
    if (widget.headerToggles != null) {
      for (var toggle in widget.headerToggles!) {
        final val = prefs.getBool('print_preview_header_${toggle.key}');
        if (val != null) {
          setState(() {
            _headerTogglesState[toggle.key] = val;
          });
        }
      }
    }

    _generatePdf();
  }

  Future<void> _saveColumnSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Save main column settings
    final mainKey = _columnsPrefsKey('main', widget.headers);
    await prefs.setStringList(
      mainKey,
      _visibleMainIndices.map((b) => b.toString()).toList(),
    );

    // Save detail column settings (if any)
    if (_detailHeaders.isNotEmpty &&
        _visibleDetailIndices.length == _detailHeaders.length) {
      final detailKey = _columnsPrefsKey('detail', _detailHeaders);
      await prefs.setStringList(
        detailKey,
        _visibleDetailIndices.map((b) => b.toString()).toList(),
      );
    }

    // Save header toggles
    if (widget.headerToggles != null) {
      for (var toggle in widget.headerToggles!) {
        if (_headerTogglesState.containsKey(toggle.key)) {
          await prefs.setBool(
            'print_preview_header_${toggle.key}',
            _headerTogglesState[toggle.key]!,
          );
        }
      }
    }
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
      margins = const pw.EdgeInsets.all(PdfPageFormat.mm * 10);
    }

    // Filter Data based on Visibility
    // 1. Filter Main Headers
    final visibleMainIndices = List<bool>.from(_visibleMainIndices);
    if (visibleMainIndices.isNotEmpty && !visibleMainIndices.any((v) => v)) {
      visibleMainIndices[0] = true;
    }

    List<String> filteredHeaders = [];
    for (int i = 0; i < widget.headers.length; i++) {
      if (visibleMainIndices[i]) {
        filteredHeaders.add(widget.headers[i]);
      }
    }

    // 2. Filter Data Rows
    List<ExpandableRowData> filteredData = widget.data.map((row) {
      // Filter Main Row
      List<String> filteredMainRow = [];
      for (int i = 0; i < row.mainRow.length; i++) {
        if (i < visibleMainIndices.length && visibleMainIndices[i]) {
          filteredMainRow.add(row.mainRow[i]);
        }
      }

      // Filter Transactions
      DetailTable? filteredTransactions;
      if (row.transactions != null) {
        final visibleDetailIndices = List<bool>.from(_visibleDetailIndices);
        if (visibleDetailIndices.isNotEmpty &&
            !visibleDetailIndices.any((v) => v)) {
          visibleDetailIndices[0] = true;
        }

        List<String> filteredTxHeaders = [];
        for (int i = 0; i < row.transactions!.headers.length; i++) {
          if (i < visibleDetailIndices.length && visibleDetailIndices[i]) {
            filteredTxHeaders.add(row.transactions!.headers[i]);
          }
        }

        List<List<String>> filteredTxData = row.transactions!.data.map((txRow) {
          List<String> newTxRow = [];
          for (int i = 0; i < txRow.length; i++) {
            if (i < visibleDetailIndices.length && visibleDetailIndices[i]) {
              String cellContent = txRow[i];
              // Apply Custom Content Filtering
              if (widget.onProcessDetailCell != null) {
                cellContent = widget.onProcessDetailCell!(
                  header: row.transactions!.headers[i],
                  content: cellContent,
                  toggles: _extraTogglesState,
                );
              }
              newTxRow.add(cellContent);
            }
          }
          return newTxRow;
        }).toList();

        filteredTransactions = DetailTable(
          title: row.transactions!.title,
          headers: filteredTxHeaders,
          data: filteredTxData,
        );
      }

      return ExpandableRowData(
        mainRow: filteredMainRow,
        details: row.details,
        transactions: filteredTransactions,
        imageUrls: row.imageUrls,
        resolvedImages: row.resolvedImages,
        isExpanded: row.isExpanded,
      );
    }).toList();

    // Call the SPECIALIZED service
    final bytes = await GenisletilebilirPrintService.generatePdf(
      format: format,
      title: widget.title,
      headers: filteredHeaders,
      data: filteredData,
      margin: margins,
      printFeatures: _showDetails,
      showHeaders: _showHeaders,
      showBackground: _showBackground,
      dateInterval: widget.dateInterval,
      headerInfo: widget.headerInfo,
      headerFieldToggles: _headerTogglesState,
    );

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
      await _saveAsPdf();
    } else {
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
              clipBehavior: Clip.none,
              children: [
                // Margin Overlay - positioned over the whole preview area
                if (_pdfBytes != null)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Dinamik Aspect Ratio Hesabı (Seçili Kağıt Boyutuna Göre)
                        final double formatAspectRatio =
                            _pageFormat.width / _pageFormat.height;
                        final double effectiveRatio = _isLandscape
                            ? (1 / formatAspectRatio)
                            : formatAspectRatio;

                        double screenW = constraints.maxWidth;
                        double screenH = constraints.maxHeight;

                        // Padding'i 100 yapıyorum ki alt çizgi kağıtla beraber ekrana tam sığsın
                        double padding = 100.0;
                        double availW = screenW - padding;
                        double availH = screenH - padding;

                        double actualPageW, actualPageH;

                        if (_isLandscape) {
                          // Landscape Modu
                          if (availW / availH > effectiveRatio) {
                            actualPageH = availH;
                            actualPageW = actualPageH * effectiveRatio;
                          } else {
                            actualPageW = availW;
                            actualPageH = actualPageW / effectiveRatio;
                          }
                        } else {
                          // Portrait Modu
                          if (availW / availH > effectiveRatio) {
                            actualPageH = availH;
                            actualPageW = actualPageH * effectiveRatio;
                          } else {
                            actualPageW = availW;
                            actualPageH = actualPageW / effectiveRatio;
                          }
                        }

                        double left = (screenW - actualPageW) / 2;
                        double top = (screenH - actualPageH) / 2;
                        final pageRect = Rect.fromLTWH(
                          left,
                          top,
                          actualPageW,
                          actualPageH,
                        );

                        return MouseRegion(
                          // setState KULLANMIYORUZ. Sadece ValueNotifier güncelliyoruz.
                          // Bu sayede PdfPreview ve ana yapı rebuild olmuyor = ZIPLAMA YOK.
                          onEnter: (_) => _showMarginsNotifier.value = true,
                          onExit: (_) => _showMarginsNotifier.value = false,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 1. PDF Kağıdı (SABİT - Asla Rebuild Olmaz)
                              Positioned(
                                left: left,
                                top: top,
                                width: actualPageW,
                                height: actualPageH,
                                child: Container(
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: PdfPreview(
                                    key: const ValueKey('pdf_preview'),
                                    build: (format) => _pdfBytes!,
                                    useActions: false,
                                    padding: EdgeInsets.zero,
                                    previewPageMargin: EdgeInsets.zero,
                                    scrollViewDecoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                    pdfPreviewPageDecoration:
                                        const BoxDecoration(
                                          color: Colors.white,
                                          boxShadow: [],
                                        ),
                                    canChangeOrientation: false,
                                    canChangePageFormat: false,
                                    allowPrinting: false,
                                    allowSharing: false,
                                    maxPageWidth: actualPageW,
                                    loadingWidget: const SizedBox(),
                                    onError: (context, error) =>
                                        Center(child: Text(tr('common.error'))),
                                  ),
                                ),
                              ),
                              // 2. Margin Overlay (ValueListenableBuilder ile Dinamik)
                              // Sadece burası dinler ve değişir.
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
                                        referencePageWidthMm: _isLandscape
                                            ? _pageFormat.height /
                                                  PdfPageFormat.mm
                                            : _pageFormat.width /
                                                  PdfPageFormat.mm,
                                        onMarginsChanged: (t, b, l, r) {
                                          setState(() {
                                            _marginTop = t;
                                            _marginBottom = b;
                                            _marginLeft = l;
                                            _marginRight = r;
                                            _marginType = 'custom';
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
                        onChanged: (val) {
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
                            onChanged: (val) {
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
                            onChanged: (val) {
                              setState(() {
                                _marginType = val!;
                                if (val == 'none') {
                                  _marginTop = 0;
                                  _marginBottom = 0;
                                  _marginLeft = 0;
                                  _marginRight = 0;
                                } else if (val == 'default') {
                                  _marginTop = 10.0;
                                  _marginBottom = 10.0;
                                  _marginLeft = 10.0;
                                  _marginRight = 10.0;
                                }
                              });
                              _generatePdf();
                            },
                          ),
                          if (_marginType == 'custom') ...[
                            const SizedBox(height: 8),
                            _buildCustomMargins(),
                          ],
                          const SizedBox(height: 16),

                          // Column Selection Button
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
                                border: Border.all(color: Colors.grey.shade200),
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
                                    _buildCheckbox(
                                      label: tr('print.headers_footers'),
                                      value: _showHeaders,
                                      onChanged: (val) {
                                        setState(() => _showHeaders = val!);
                                        _generatePdf();
                                      },
                                    ),
                                    if (!widget.hideFeaturesCheckbox)
                                      _buildCheckbox(
                                        label: tr('print.show_features'),
                                        value: _showDetails,
                                        onChanged: (val) {
                                          setState(() => _showDetails = val!);
                                          _generatePdf();
                                        },
                                      ),
                                    const SizedBox(height: 12),
                                    // Save Button (PDF)
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
                                    // Save Button (Excel)
                                    OutlinedButton.icon(
                                      onPressed:
                                          (!LisansServisi().isLiteMode ||
                                              LiteKisitlari.isExcelExportActive)
                                          ? _saveAsExcel
                                          : null,
                                      icon: const Icon(
                                        Icons.table_view,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      label: Text(tr('print.save_as_excel')),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(
                                          color: Colors.green,
                                          width: 0.5,
                                        ),
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
    // Create local copies for dialog state
    final List<bool> localMainIndices = List.from(_visibleMainIndices);
    List<bool> localDetailIndices = List.from(_visibleDetailIndices);
    Map<String, bool> localExtraToggles = Map.from(_extraTogglesState);
    Map<String, bool> localHeaderToggles = Map.from(_headerTogglesState);

    bool isAllMainSelected() {
      return localMainIndices.every((v) => v);
    }

    bool isAllDetailSelected() {
      return localDetailIndices.every((v) => v);
    }

    void toggleAllMain(bool? value) {
      for (int i = 0; i < localMainIndices.length; i++) {
        localMainIndices[i] = value ?? false;
      }
    }

    void toggleAllDetail(bool? value) {
      for (int i = 0; i < localDetailIndices.length; i++) {
        localDetailIndices[i] = value ?? false;
      }
    }

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
                      // --- MAIN TABLE SECTION ---
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.mainTableLabel ?? tr('common.main_table'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                                fontSize: 14,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.9,
                              child: Row(
                                children: [
                                  Text(
                                    tr('common.select_all'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Checkbox(
                                    value: isAllMainSelected(),
                                    activeColor: const Color(0xFF2C3E50),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        toggleAllMain(val);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Main Columns Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(widget.headers.length, (index) {
                          return _buildConfigCheckbox(
                            setDialogState,
                            localMainIndices,
                            index,
                            widget.headers[index],
                          );
                        }),
                      ),
                      // --- DETAIL TABLE SECTION (only show if details are enabled) ---
                      if (_showDetails && _detailHeaders.isNotEmpty) ...[
                        const SizedBox(height: 24),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.detailTableLabel ??
                                    tr('common.last_movements'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                  fontSize: 14,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.9,
                                child: Row(
                                  children: [
                                    Text(
                                      tr('common.select_all'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Checkbox(
                                      value: isAllDetailSelected(),
                                      activeColor: const Color(0xFF2C3E50),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          toggleAllDetail(val);
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_detailHeaders.length, (
                            index,
                          ) {
                            return _buildConfigCheckbox(
                              setDialogState,
                              localDetailIndices,
                              index,
                              _detailHeaders[index],
                            );
                          }),
                        ),
                      ],
                      // --- EXTRA TOGGLES SECTION ---
                      if (_showDetails &&
                          widget.extraDetailToggles != null &&
                          widget.extraDetailToggles!.isNotEmpty) ...[
                        const SizedBox(height: 24),
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
                            tr('common.content_settings'), // İçerik Ayarları
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
                          children: widget.extraDetailToggles!.map((toggle) {
                            return _buildExtraToggleCheckbox(
                              setDialogState,
                              localExtraToggles,
                              toggle,
                            );
                          }).toList(),
                        ),
                      ],

                      // --- HEADER FIELDS SECTION ---
                      if (widget.headerToggles != null &&
                          widget.headerToggles!.isNotEmpty) ...[
                        const SizedBox(height: 24),
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
                            tr('accounts.title') == tr('accounts.title')
                                ? tr('common.header_fields')
                                : tr('common.header_fields'),
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
                          children: widget.headerToggles!.map((toggle) {
                            return _buildExtraToggleCheckbox(
                              setDialogState,
                              localHeaderToggles,
                              toggle,
                            );
                          }).toList(),
                        ),
                      ],
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
                    if (localMainIndices.isNotEmpty &&
                        !localMainIndices.any((v) => v)) {
                      localMainIndices[0] = true;
                    }
                    if (localDetailIndices.isNotEmpty &&
                        !localDetailIndices.any((v) => v)) {
                      localDetailIndices[0] = true;
                    }
                    // Update main state
                    setState(() {
                      _visibleMainIndices = localMainIndices;
                      _visibleDetailIndices = localDetailIndices;
                      _extraTogglesState.clear();
                      _extraTogglesState.addAll(localExtraToggles);
                      _headerTogglesState.clear();
                      _headerTogglesState.addAll(localHeaderToggles);
                    });
                    _saveColumnSettings(); // Save preferences
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

  Widget _buildConfigCheckbox(
    StateSetter setDialogState,
    List<bool> localList,
    int index,
    String label,
  ) {
    return SizedBox(
      width: 170,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          setDialogState(() {
            localList[index] = !localList[index];
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
                  value: localList[index],
                  activeColor: const Color(0xFF2C3E50),
                  onChanged: (val) {
                    setDialogState(() {
                      localList[index] = val ?? true;
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
                  label,
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

  Future<void> _saveAsExcel() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await GenisletilebilirExcelService.generateExcel(
        title: widget.title,
        headers: widget.headers,
        data: widget.data,
        printFeatures: _showDetails,
        dateInterval: widget.dateInterval,
      );

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

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

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
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              final d = double.tryParse(val);
              if (d != null) onChanged(d);
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
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                icon: const Icon(Icons.arrow_drop_down, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: Colors.grey, width: 1),
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
