import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../temalar/app_theme.dart';
import '../modeller/dashboard_ozet_modeli.dart';

/// Dashboard Analitik Grafik Kartı
/// Syncfusion SfCartesianChart ile 30 günlük Spline Area Chart.
/// Satış (Kırmızı) ve Alış (Koyu Mavi).
class DashboardGrafikKarti extends StatefulWidget {
  final List<GunlukTutar> satis30Gun;
  final List<GunlukTutar> alis30Gun;
  final VoidCallback? onTap;

  const DashboardGrafikKarti({
    super.key,
    required this.satis30Gun,
    required this.alis30Gun,
    this.onTap,
  });

  @override
  State<DashboardGrafikKarti> createState() => _DashboardGrafikKartiState();
}

class _DashboardGrafikKartiState extends State<DashboardGrafikKarti> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
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
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.01, 1.01, 1)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.grey.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppPalette.slate.withValues(alpha: 0.1)
                    : AppPalette.slate.withValues(alpha: 0.06),
                blurRadius: _isHovered ? 20 : 12,
                offset: const Offset(0, 4),
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
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E5F74).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: Color(0xFF1E5F74),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Satış / Alış Eğrisi',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppPalette.slate,
                      ),
                    ),
                  ),
                  // Legend
                  _buildLegend('Satış', AppPalette.red),
                  const SizedBox(width: 12),
                  _buildLegend('Alış', const Color(0xFF1E5F74)),
                ],
              ),
              const SizedBox(height: 16),
              // Grafik
              SizedBox(
                height: 220,
                child: SfCartesianChart(
                  plotAreaBorderWidth: 0,
                  margin: EdgeInsets.zero,
                  primaryXAxis: DateTimeAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: AppPalette.grey.withValues(alpha: 0.7),
                    ),
                    intervalType: DateTimeIntervalType.days,
                    interval: 7,
                  ),
                  primaryYAxis: NumericAxis(
                    majorGridLines: MajorGridLines(
                      width: 0.5,
                      color: AppPalette.grey.withValues(alpha: 0.15),
                      dashArray: const <double>[4, 4],
                    ),
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: AppPalette.grey.withValues(alpha: 0.7),
                    ),
                    numberFormat: _compactFormat(),
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    header: '',
                    canShowMarker: true,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                  series: <CartesianSeries>[
                    SplineAreaSeries<GunlukTutar, DateTime>(
                      name: 'Satış',
                      dataSource: widget.satis30Gun,
                      xValueMapper: (data, _) => data.tarih,
                      yValueMapper: (data, _) => data.tutar,
                      color: AppPalette.red.withValues(alpha: 0.15),
                      borderColor: AppPalette.red,
                      borderWidth: 2.5,
                      splineType: SplineType.natural,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppPalette.red.withValues(alpha: 0.2),
                          AppPalette.red.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    SplineAreaSeries<GunlukTutar, DateTime>(
                      name: 'Alış',
                      dataSource: widget.alis30Gun,
                      xValueMapper: (data, _) => data.tarih,
                      yValueMapper: (data, _) => data.tutar,
                      color: const Color(0xFF1E5F74).withValues(alpha: 0.15),
                      borderColor: const Color(0xFF1E5F74),
                      borderWidth: 2.5,
                      splineType: SplineType.natural,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1E5F74).withValues(alpha: 0.2),
                          const Color(0xFF1E5F74).withValues(alpha: 0.02),
                        ],
                      ),
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

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppPalette.grey.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  dynamic _compactFormat() {
    // Basit K/M formatı kullanmak yerine intl NumberFormat
    // Syncfusion kendi NumberFormat'ını kullanır
    return null;
  }
}
