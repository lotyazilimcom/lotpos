import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Dashboard Shimmer İskelet Yükleme Efekti
/// Veriler yüklenirken gösterilecek iskelet yapı.
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossCount = width >= 1200
                ? 4
                : width >= 800
                    ? 2
                    : 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Durum Şeridi shimmer
                _shimmerDurumSeridi(),
                const SizedBox(height: 20),
                // Hero KPI kartları shimmer
                _shimmerGrid(crossCount: crossCount, itemCount: 5, height: 140),
                const SizedBox(height: 24),
                // Grafik + Uyarı alanı shimmer
                _shimmerAnaliticRow(crossCount >= 2),
                const SizedBox(height: 24),
                // Orta bant finansal kartlar
                _shimmerGrid(crossCount: crossCount, itemCount: 6, height: 110),
                const SizedBox(height: 24),
                // Hızlı işlemler shimmer
                _shimmerHizliIslemler(),
                const SizedBox(height: 24),
                // Son işlemler shimmer
                _shimmerSonIslemler(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _shimmerDurumSeridi() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _shimmerGrid({
    required int crossCount,
    required int itemCount,
    required double height,
  }) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(itemCount, (_) {
        final itemWidth = crossCount == 1
            ? double.infinity
            : crossCount == 2
                ? 300.0
                : 200.0;
        return SizedBox(
          width: crossCount == 1 ? double.infinity : itemWidth,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }),
    );
  }

  Widget _shimmerAnaliticRow(bool isWide) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  Widget _shimmerHizliIslemler() {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _shimmerSonIslemler() {
    return Column(
      children: List.generate(
        5,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
