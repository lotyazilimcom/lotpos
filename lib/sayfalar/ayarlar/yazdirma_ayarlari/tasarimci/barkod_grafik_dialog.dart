import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:patisyov10/sayfalar/ayarlar/yazdirma_ayarlari/modeller/barkod_grafik_model.dart';
import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';

class BarkodGrafikDialog extends StatefulWidget {
  final BarkodGrafikModel? initialValue;

  const BarkodGrafikDialog({super.key, this.initialValue});

  static Future<BarkodGrafikModel?> show(
    BuildContext context, {
    BarkodGrafikModel? initialValue,
  }) {
    return showDialog<BarkodGrafikModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BarkodGrafikDialog(initialValue: initialValue),
    );
  }

  @override
  State<BarkodGrafikDialog> createState() => _BarkodGrafikDialogState();
}

class _BarkodGrafikDialogState extends State<BarkodGrafikDialog> {
  static const Color _accent = Color(0xFF2C3E50);
  static const Color _surface = Color(0xFFF8F9FA);

  late String _standard;

  BarkodGrafikStandartMeta get _meta => BarkodGrafikKatalog.metaFor(_standard);

  @override
  void initState() {
    super.initState();
    _standard =
        widget.initialValue?.standard ?? BarkodGrafikStandartlari.code128Auto;
  }

  BarkodGrafikModel get _currentValue => BarkodGrafikModel(standard: _standard);

  void _closeWithDraft() {
    Navigator.of(context).pop(_currentValue);
  }

  void _save() {
    Navigator.of(context).pop(_currentValue);
  }

  String _supportLabel() => tr(
    _meta.isNativeSupported
        ? 'print.barcode.preview.native'
        : 'print.barcode.preview.compatible',
  );

  String _previewKindLabel() =>
      tr('print.barcode.preview.${_meta.previewKind}');

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF606368),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF606368),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF202124),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewGlyph() {
    return Container(
      width: double.infinity,
      height: 168,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: CustomPaint(
        painter: _BarcodeStylePreviewPainter(
          kind: _meta.previewKind,
          seed: _meta.code,
          color: _accent,
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return _buildCard(
      icon: Icons.qr_code_2_rounded,
      title: tr('print.barcode.dialog.mode_title'),
      description: tr('print.barcode.dialog.mode_description'),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _standard,
            decoration: _inputDecoration(
              label: tr('print.barcode.dialog.standard_label'),
            ),
            items: BarkodGrafikKatalog.standartlar.map((meta) {
              return DropdownMenuItem<String>(
                value: meta.code,
                child: Text(tr(meta.labelKey)),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _standard = value);
            },
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _meta.isNativeSupported
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _meta.isNativeSupported
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFFCD34D),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _meta.isNativeSupported
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: _meta.isNativeSupported
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB45309),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(_meta.descriptionKey),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: _meta.isNativeSupported
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return _buildCard(
      icon: Icons.tune_rounded,
      title: tr('print.barcode.preview.title'),
      description: tr('print.barcode.preview.description'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewGlyph(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  tr('print.barcode.preview.category'),
                  _previewKindLabel(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetric(
                  tr('print.barcode.preview.engine'),
                  _supportLabel(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetric(tr('print.barcode.preview.sample'), _meta.sampleData),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: _accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('print.barcode.dialog.title'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF202124),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('print.barcode.dialog.subtitle'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF606368),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _closeWithDraft,
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF5F6368),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;
                    final form = SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildFormCard(),
                    );
                    final preview = SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                      child: _buildPreviewCard(),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: form),
                          Container(width: 1, color: const Color(0xFFE8EAED)),
                          SizedBox(width: 320, child: preview),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildFormCard(),
                          const SizedBox(height: 16),
                          _buildPreviewCard(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _closeWithDraft,
                      child: Text(tr('common.cancel')),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(tr('common.save')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeStylePreviewPainter extends CustomPainter {
  final String kind;
  final String seed;
  final Color color;

  const _BarcodeStylePreviewPainter({
    required this.kind,
    required this.seed,
    required this.color,
  });

  int _seedValue() {
    var value = 0x45D9F3B;
    for (final codeUnit in seed.codeUnits) {
      value ^= codeUnit;
      value = (value * 1103515245 + 12345) & 0x7FFFFFFF;
    }
    return value;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.9);
    final fadedPaint = Paint()..color = color.withValues(alpha: 0.18);
    final seedValue = _seedValue();

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      fadedPaint,
    );

    switch (kind) {
      case BarkodGrafikOnizlemeTuru.matrix:
        _paintMatrix(canvas, size, paint, seedValue);
        break;
      case BarkodGrafikOnizlemeTuru.stacked:
        _paintStacked(canvas, size, paint, seedValue);
        break;
      case BarkodGrafikOnizlemeTuru.postal:
        _paintPostal(canvas, size, paint, seedValue);
        break;
      default:
        _paintLinear(canvas, size, paint, seedValue);
        break;
    }
  }

  void _paintLinear(Canvas canvas, Size size, Paint paint, int seedValue) {
    final left = size.width * 0.08;
    final top = size.height * 0.18;
    final width = size.width * 0.84;
    final height = size.height * 0.62;
    final barCount = math.max(18, (width / 6).floor());
    final barWidth = width / (barCount * 1.4);

    for (var index = 0; index < barCount; index++) {
      final barHeightFactor =
          0.45 + (((seedValue >> (index % 16)) & 0xFF) / 255) * 0.55;
      final x = left + (index * barWidth * 1.4);
      final barHeight = height * barHeightFactor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top + (height - barHeight), barWidth, barHeight),
          const Radius.circular(1.2),
        ),
        paint,
      );
    }
  }

  void _paintStacked(Canvas canvas, Size size, Paint paint, int seedValue) {
    final left = size.width * 0.08;
    final top = size.height * 0.16;
    final width = size.width * 0.84;
    final rowHeight = size.height * 0.12;
    for (var row = 0; row < 5; row++) {
      final y = top + (row * rowHeight * 1.18);
      final barCount = 12 + row;
      final barWidth = width / (barCount * 1.45);
      for (var index = 0; index < barCount; index++) {
        final heightFactor =
            0.45 + ((((seedValue >> ((index + row) % 18)) & 0x7F) / 127) * 0.5);
        final x = left + (index * barWidth * 1.45);
        final barHeight = rowHeight * heightFactor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, barWidth, barHeight),
            const Radius.circular(1),
          ),
          paint,
        );
      }
    }
  }

  void _paintMatrix(Canvas canvas, Size size, Paint paint, int seedValue) {
    final side = math.min(size.width, size.height) * 0.72;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final modules = 16;
    final moduleSize = side / modules;

    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        final mixed =
            (seedValue + (row * 92821) + (col * 68917) + (row * col * 1237)) &
            0x7FFFFFFF;
        final on = mixed % 7 < 3;
        if (!on) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * moduleSize,
            origin.dy + row * moduleSize,
            moduleSize * 0.92,
            moduleSize * 0.92,
          ),
          paint,
        );
      }
    }
  }

  void _paintPostal(Canvas canvas, Size size, Paint paint, int seedValue) {
    final left = size.width * 0.08;
    final width = size.width * 0.84;
    final bottom = size.height * 0.8;
    final barCount = 32;
    final barWidth = width / (barCount * 1.55);
    final fullHeight = size.height * 0.52;
    final halfHeight = size.height * 0.28;

    for (var index = 0; index < barCount; index++) {
      final x = left + (index * barWidth * 1.55);
      final mode = ((seedValue >> (index % 20)) + index) % 4;
      final y = switch (mode) {
        0 => bottom - fullHeight,
        1 => bottom - halfHeight,
        2 => bottom - fullHeight,
        _ => bottom - halfHeight,
      };
      final height = mode == 2 || mode == 3 ? fullHeight : halfHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodeStylePreviewPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.seed != seed ||
        oldDelegate.color != color;
  }
}
