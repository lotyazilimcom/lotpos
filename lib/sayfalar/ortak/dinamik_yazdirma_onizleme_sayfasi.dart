import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../servisler/yerel_ag_yazdirma_servisi.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/yazdirma/dinamik_yazdirma_servisi.dart';
import '../../yardimcilar/yazdirma/yazdirma_erisim_kontrolu.dart';
import '../ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';
import 'mobil_tablet_yazdirma_onizleme_kabugu.dart';

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
  bool get _printingDisabled => YazdirmaErisimKontrolu.mobilBulutYazdirmaPasif;
  bool get _useCompactLayout =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _useDesktopRelayPrinter =>
      YazdirmaErisimKontrolu.mobilYerelAgMasaustuYazdirmaAktif;

  Printer? _selectedPrinter;
  List<Printer> _printers = [];

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
      final printers = _useDesktopRelayPrinter
          ? await YerelAgYazdirmaServisi().mobilTabletYazicilariniGetir()
          : _useCompactLayout
          ? const <Printer>[]
          : await Printing.listPrinters();
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _selectedPrinter = _printers.isNotEmpty ? _printers.first : null;
      });
    } catch (e) {
      debugPrint('Error fetching printers: $e');
    }
  }

  Future<void> _generatePdf() async {
    debugPrint('--- [DinamikYazdirmaOnizlemeSayfasi] _generatePdf STARTED ---');
    setState(() => _isLoading = true);

    try {
      final doc = await DinamikYazdirmaServisi().pdfOlustur(
        sablon: widget.sablon,
        veri: widget.veri,
      );

      final bytes = await doc.save();

      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error generating PDF preview: $e');
      if (!mounted) return;
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

  Future<void> _handlePrint() async {
    if (_printingDisabled || _pdfBytes == null) return;

    if (_useDesktopRelayPrinter && _selectedPrinter != null) {
      try {
        await YerelAgYazdirmaServisi().yazdirmaIstegiGonder(
          title: '${widget.sablon.name}_Çıktı',
          pdfBytes: _pdfBytes!,
          printer: _selectedPrinter!,
          copies: 1,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'print.mobile.remote.queued',
              ).replaceAll('{printer}', _selectedPrinter!.name),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'print.mobile.remote.failed',
              ).replaceAll('{error}', e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_selectedPrinter == null) {
      await _saveAsPdf();
      return;
    }

    await Printing.directPrintPdf(
      printer: _selectedPrinter!,
      onLayout: (_) => _pdfBytes!,
      name: '${widget.sablon.name}_Çıktı',
    );
  }

  Future<void> _saveAsPdf() async {
    if (_pdfBytes == null) return;

    final fileName = '${widget.sablon.name}_Çıktı.pdf';
    if (_useCompactLayout) {
      await Printing.sharePdf(bytes: _pdfBytes!, filename: fileName);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPath = prefs.getString('last_export_path');

    final result = await getSaveLocation(
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

    final path = result.path;
    final file = File(path);
    await file.writeAsBytes(_pdfBytes!);

    final parentDir = file.parent.path;
    await prefs.setString('last_export_path', parentDir);

    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (_useCompactLayout) {
      return _buildCompactView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF323639),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_pdfBytes != null)
                  Container(
                    color: const Color(0xFF323639),
                    child: PdfPreview(
                      build: (_) => _pdfBytes!,
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
                Padding(
                  padding: const EdgeInsets.all(16),
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDropdownRow<Printer?>(
                        label: tr('print.destination'),
                        value: _selectedPrinter,
                        items: _buildDestinationItems(),
                        onChanged: (val) {
                          setState(() => _selectedPrinter = val);
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildTemplateInfoCard(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
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
                        onPressed: _printingDisabled || _pdfBytes == null
                            ? null
                            : _handlePrint,
                        icon: const Icon(Icons.print),
                        label: Text(tr('common.print')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _printingDisabled
                              ? Colors.grey.shade300
                              : const Color(0xFF2C3E50),
                          foregroundColor: _printingDisabled
                              ? Colors.grey.shade600
                              : Colors.white,
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

  Widget _buildCompactView() {
    return MobilTabletYazdirmaOnizlemeKabugu(
      title: widget.sablon.name,
      subtitle: tr('print.mobile.preview.subtitle'),
      preview: _buildCompactPreview(),
      statusCard: _buildCompactStatusCard(),
      summaryLabel: tr('print.destination'),
      summaryValue: _selectedPrinter?.name ?? tr('print.destination.pdf'),
      summaryHint: _useDesktopRelayPrinter
          ? (_selectedPrinter != null
                ? tr(
                    'print.mobile.remote.summary',
                  ).replaceAll('{printer}', _selectedPrinter!.name)
                : tr('print.mobile.remote.not_configured'))
          : tr('print.mobile.preview.settings_hint'),
      primaryActionLabel: _selectedPrinter == null
          ? tr('print.save_as_pdf')
          : tr('common.print'),
      primaryActionIcon: _selectedPrinter == null
          ? Icons.picture_as_pdf_rounded
          : Icons.print_rounded,
      onPrimaryAction: _printingDisabled ? null : _handlePrint,
      secondaryActionLabel: tr('common.cancel'),
      onSecondaryAction: () => Navigator.pop(context),
      onBack: () => Navigator.pop(context),
      settingsChildren: _buildCompactSettingsChildren(),
    );
  }

  Widget _buildCompactPreview() {
    if (_pdfBytes == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2C3E50)),
      );
    }

    return Container(
      color: const Color(0xFFF3F5F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final horizontalPadding = availableWidth >= 700 ? 10.0 : 4.0;
          final maxPageWidth = (availableWidth - (horizontalPadding * 2))
              .clamp(220.0, 720.0)
              .toDouble();

          return Stack(
            children: [
              PdfPreview(
                build: (_) => _pdfBytes!,
                useActions: false,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  4,
                  horizontalPadding,
                  8,
                ),
                previewPageMargin: const EdgeInsets.only(bottom: 10),
                scrollViewDecoration: const BoxDecoration(
                  color: Color(0xFFF3F5F7),
                ),
                pdfPreviewPageDecoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0F172A),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                canChangeOrientation: false,
                canChangePageFormat: false,
                allowPrinting: false,
                allowSharing: false,
                maxPageWidth: maxPageWidth,
                dpi: 144,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2C3E50)),
                ),
                onError: (context, error) =>
                    Center(child: Text(tr('common.error'))),
              ),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2C3E50)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget? _buildCompactStatusCard() {
    if (!_useDesktopRelayPrinter) return null;

    final hasPrinter = _selectedPrinter != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPrinter ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPrinter
              ? const Color(0xFF10B981).withValues(alpha: 0.18)
              : const Color(0xFFF59E0B).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: hasPrinter
                  ? const Color(0xFF10B981).withValues(alpha: 0.14)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasPrinter
                  ? Icons.desktop_windows_rounded
                  : Icons.warning_amber_rounded,
              color: hasPrinter
                  ? const Color(0xFF047857)
                  : const Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPrinter
                      ? tr('print.mobile.remote.card.title')
                      : tr('print.mobile.remote.card.warning_title'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasPrinter
                        ? const Color(0xFF065F46)
                        : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPrinter
                      ? tr(
                          'print.mobile.remote.card.description',
                        ).replaceAll('{printer}', _selectedPrinter!.name)
                      : tr('print.mobile.remote.card.warning_description'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: hasPrinter
                        ? const Color(0xFF047857)
                        : const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCompactSettingsChildren() {
    return [
      _buildCompactSection(
        title: tr('print.destination'),
        icon: Icons.route_rounded,
        child: _buildDropdownRow<Printer?>(
          label: tr('print.destination'),
          value: _selectedPrinter,
          items: _buildDestinationItems(),
          onChanged: (val) {
            setState(() => _selectedPrinter = val);
          },
        ),
      ),
      const SizedBox(height: 12),
      _buildCompactSection(
        title: tr('print.preview.template_info'),
        icon: Icons.description_outlined,
        child: _buildTemplateInfoCard(),
      ),
      const SizedBox(height: 12),
      _buildCompactSection(
        title: tr('print.options'),
        icon: Icons.picture_as_pdf_outlined,
        child: OutlinedButton.icon(
          onPressed: _saveAsPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(tr('print.save_as_pdf')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    ];
  }

  List<DropdownMenuItem<Printer?>> _buildDestinationItems() {
    return [
      DropdownMenuItem(
        value: null,
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 18,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(tr('print.destination.pdf')),
          ],
        ),
      ),
      ..._printers.map(
        (printer) => DropdownMenuItem(
          value: printer,
          child: Row(
            children: [
              Icon(
                _useDesktopRelayPrinter
                    ? Icons.desktop_windows_rounded
                    : Icons.print_rounded,
                size: 18,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(printer.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildTemplateInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2C3E50).withValues(alpha: 0.2),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
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
            tr(
              'print.preview.paper',
            ).replaceAll('{paper}', widget.sablon.paperSize ?? ''),
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
    );
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF2C3E50)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
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
            borderRadius: BorderRadius.circular(10),
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
