import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/yazdirma/dinamik_yazdirma_servisi.dart';
import '../ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';
import '../../bilesenler/margin_overlay.dart';

class DinamikSablonPreviewScreen extends StatefulWidget {
  final String title;
  final YazdirmaSablonuModel sablon;
  final Map<String, dynamic> veri;

  const DinamikSablonPreviewScreen({
    super.key,
    required this.title,
    required this.sablon,
    required this.veri,
  });

  @override
  State<DinamikSablonPreviewScreen> createState() =>
      _DinamikSablonPreviewScreenState();
}

class _DinamikSablonPreviewScreenState
    extends State<DinamikSablonPreviewScreen> {
  // Print Settings
  late PdfPageFormat _pageFormat;
  late bool _isLandscape;
  int _copies = 1;
  bool _showHeaders = true;
  bool _showBackground = true;

  // Printer & Destination
  Printer? _selectedPrinter;
  List<Printer> _printers = [];

  // Margins
  String _marginType = 'none';
  double _marginTop = 10.0;
  double _marginBottom = 10.0;
  double _marginLeft = 10.0;
  double _marginRight = 10.0;
  bool _showMargins = false;

  // Pages & Scale
  String _pagesType = 'all';
  String _scaleType = 'default';

  // Preview State
  Uint8List? _pdfBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize from template
    _pageFormat = DinamikYazdirmaServisi().getFormat(widget.sablon);
    _isLandscape = widget.sablon.isLandscape;

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
    setState(() => _isLoading = true);

    final format = _isLandscape ? _pageFormat.landscape : _pageFormat.portrait;

    // Kenar boşluklarını hesapla (mm -> point)
    pw.EdgeInsets margins;
    if (_marginType == 'none') {
      margins = pw.EdgeInsets.zero;
    } else if (_marginType == 'custom') {
      margins = pw.EdgeInsets.fromLTRB(
        _marginLeft * PdfPageFormat.mm,
        _marginTop * PdfPageFormat.mm,
        _marginRight * PdfPageFormat.mm,
        _marginBottom * PdfPageFormat.mm,
      );
    } else {
      // Varsayılan: Standart 40 point (~14mm) veya Şablon için 0
      // Kullanıcı deneyimi için standartı (40) kullanıyoruz, sığmazsa kullanıcı 'Yok' seçebilir.
      margins = const pw.EdgeInsets.all(40);
    }

    try {
      final doc = await DinamikYazdirmaServisi().pdfOlustur(
        sablon: widget.sablon,
        veri: widget.veri,
        overrideFormat: format,
        margin: margins,
      );

      final bytes = await doc.save();

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PDF Oluşturma Hatası: $e');
      if (mounted) setState(() => _isLoading = false);
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
                if (_pdfBytes != null)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double formatAspectRatio =
                            _pageFormat.width / _pageFormat.height;
                        final double effectiveRatio = _isLandscape
                            ? (1 / formatAspectRatio)
                            : formatAspectRatio;

                        double screenW = constraints.maxWidth;
                        double screenH = constraints.maxHeight;
                        double padding = 100.0;
                        double availW = screenW - padding;
                        double availH = screenH - padding;

                        double actualPageW, actualPageH;
                        if (availW / availH > effectiveRatio) {
                          actualPageH = availH;
                          actualPageW = actualPageH * effectiveRatio;
                        } else {
                          actualPageW = availW;
                          actualPageH = actualPageW / effectiveRatio;
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
                          onEnter: (_) => setState(() => _showMargins = true),
                          onExit: (_) => setState(() => _showMargins = false),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
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
                                    pdfPreviewPageDecoration:
                                        const BoxDecoration(
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
                              IgnorePointer(
                                ignoring: !_showMargins,
                                child: Visibility(
                                  visible: _showMargins,
                                  child: MarginOverlay(
                                    marginTop: _marginTop,
                                    marginBottom: _marginBottom,
                                    marginLeft: _marginLeft,
                                    marginRight: _marginRight,
                                    pageRect: pageRect,
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
                    heroTag: 'back_btn',
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          // Right Side: Sidebar (Exact match to PrintPreviewScreen)
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
                        onChanged: (val) =>
                            setState(() => _selectedPrinter = val),
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
                        onChanged: (val) => setState(() => _pagesType = val!),
                      ),
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
                            onChanged: (val) => setState(
                              () => _copies = int.tryParse(val) ?? 1,
                            ),
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
                          setState(() => _isLandscape = val == 'landscape');
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
                              setState(() => _marginType = val!);
                              _generatePdf();
                            },
                          ),
                          if (_marginType == 'custom') ...[
                            const SizedBox(height: 8),
                            _buildCustomMargins(),
                          ],
                          const SizedBox(height: 16),
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
                            onChanged: (val) =>
                                setState(() => _scaleType = val!),
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
                                      onChanged: (val) =>
                                          setState(() => _showHeaders = val!),
                                    ),
                                    _buildCheckbox(
                                      label: tr('print.background_graphics'),
                                      value: _showBackground,
                                      onChanged: (val) => setState(
                                        () => _showBackground = val!,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
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
                _generatePdf();
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
    required ValueChanged<T?> onChanged,
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
