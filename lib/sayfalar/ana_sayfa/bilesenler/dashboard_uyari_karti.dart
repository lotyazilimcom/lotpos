import 'package:flutter/material.dart';
import '../../../temalar/app_theme.dart';
import '../modeller/dashboard_ozet_modeli.dart';

/// Dashboard Uyarı Kartı — Kritik Stok & Yaklaşan Vadeler
class DashboardUyariKarti extends StatefulWidget {
  final List<KritikStokItem> kritikStoklar;
  final List<YaklasanVade> yaklasanVadeler;
  final VoidCallback? onStokTap;
  final VoidCallback? onCekTap;
  final VoidCallback? onSenetTap;

  const DashboardUyariKarti({
    super.key,
    required this.kritikStoklar,
    required this.yaklasanVadeler,
    this.onStokTap,
    this.onCekTap,
    this.onSenetTap,
  });

  @override
  State<DashboardUyariKarti> createState() => _DashboardUyariKartiState();
}

class _DashboardUyariKartiState extends State<DashboardUyariKarti> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
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
                  ? AppPalette.amber.withValues(alpha: 0.1)
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
                    color: AppPalette.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppPalette.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Risk Merkezi',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppPalette.slate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kritik Stoklar
            if (widget.kritikStoklar.isNotEmpty) ...[
              _buildSectionTitle(
                'Kritik Stok (≤ 5)',
                Icons.inventory_2_outlined,
                AppPalette.red,
              ),
              const SizedBox(height: 8),
              ...widget.kritikStoklar.take(4).map((s) => _buildStokItem(s)),
              const SizedBox(height: 16),
            ],

            // Yaklaşan Vadeler
            if (widget.yaklasanVadeler.isNotEmpty) ...[
              _buildSectionTitle(
                'Yaklaşan Vadeler',
                Icons.event_note_rounded,
                AppPalette.amber,
              ),
              const SizedBox(height: 8),
              ...widget.yaklasanVadeler.take(4).map((v) => _buildVadeItem(v)),
            ],

            if (widget.kritikStoklar.isEmpty && widget.yaklasanVadeler.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 36,
                        color: const Color(0xFF27AE60).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Herhangi bir uyarı yok',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppPalette.grey.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildStokItem(KritikStokItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onStokTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppPalette.red.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppPalette.red.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.urunAdi,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.slate,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.mevcutStok.toStringAsFixed(0)} ${item.birim}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVadeItem(YaklasanVade item) {
    final kalanGun = item.vadeTarihi.difference(DateTime.now()).inDays;
    final riskRenk = kalanGun <= 3 ? AppPalette.red : AppPalette.amber;
    final turRenk = item.tur == 'Çek'
        ? const Color(0xFF2196F3)
        : const Color(0xFFFF9800);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: item.tur == 'Çek' ? widget.onCekTap : widget.onSenetTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: riskRenk.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: riskRenk.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: turRenk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.tur,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: turRenk,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.cariAdi,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.slate,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$kalanGun gün',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: riskRenk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
