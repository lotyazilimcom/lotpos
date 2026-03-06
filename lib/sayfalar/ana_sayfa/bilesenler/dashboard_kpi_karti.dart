import 'package:flutter/material.dart';
import '../../../temalar/app_theme.dart';
import '../../../yardimcilar/format_yardimcisi.dart';

/// Dashboard Hero KPI Kartı
/// Büyük tutar, değişim oku, soft renkli ikon ve mini sparkline.
class DashboardKpiKarti extends StatefulWidget {
  final String baslik;
  final double tutar;
  final double degisimYuzde;
  final IconData ikon;
  final Color renk;
  final List<double> sparkline;
  final VoidCallback? onTap;
  final String paraBirimi;

  const DashboardKpiKarti({
    super.key,
    required this.baslik,
    required this.tutar,
    required this.degisimYuzde,
    required this.ikon,
    required this.renk,
    this.sparkline = const [],
    this.onTap,
    this.paraBirimi = '₺',
  });

  @override
  State<DashboardKpiKarti> createState() => _DashboardKpiKartiState();
}

class _DashboardKpiKartiState extends State<DashboardKpiKarti> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.degisimYuzde >= 0;
    final degisimRenk = isPositive ? const Color(0xFF27AE60) : AppPalette.red;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.02, 1.02, 1)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.renk.withValues(alpha: 0.3)
                  : AppPalette.grey.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.renk.withValues(alpha: 0.12)
                    : AppPalette.slate.withValues(alpha: 0.06),
                blurRadius: _isHovered ? 20 : 12,
                offset: const Offset(0, 4),
                spreadRadius: _isHovered ? 2 : 0,
              ),
              BoxShadow(
                color: AppPalette.slate.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst sıra: İkon + Başlık
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.renk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.ikon,
                      color: widget.renk,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.baslik,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppPalette.slate,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tutar
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${FormatYardimcisi.sayiFormatlaOndalikli(widget.tutar)} ${widget.paraBirimi}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AppPalette.slate,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Alt sıra: Değişim yüzdesi + Sparkline
              Row(
                children: [
                  // Değişim yüzdesi
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: degisimRenk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 14,
                          color: degisimRenk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? '+' : ''}${widget.degisimYuzde.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: degisimRenk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Mini Sparkline
                  if (widget.sparkline.isNotEmpty)
                    SizedBox(
                      width: 80,
                      height: 28,
                      child: CustomPaint(
                        painter: _SparklinePainter(
                          data: widget.sparkline,
                          renk: widget.renk,
                        ),
                      ),
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

/// Mini sparkline çizici
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color renk;

  _SparklinePainter({required this.data, required this.renk});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = renk
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Gradient altlık
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          renk.withValues(alpha: 0.15),
          renk.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.renk != renk;
  }
}
