import 'package:flutter/material.dart';
import '../../../temalar/app_theme.dart';

/// Dashboard Durum Şeridi (Top Bar)
/// Aktif şirket, bağlantı modu, son yenilenme zamanı ve tarih filtresi.
class DashboardDurumSeridi extends StatelessWidget {
  final String sirketAdi;
  final String baglantiModu;
  final DateTime sonYenilenme;
  final String seciliFiltre; // 'bugun', 'buHafta', 'buAy'
  final ValueChanged<String> onFiltreSecildi;
  final VoidCallback onYenile;

  const DashboardDurumSeridi({
    super.key,
    required this.sirketAdi,
    required this.baglantiModu,
    required this.sonYenilenme,
    required this.seciliFiltre,
    required this.onFiltreSecildi,
    required this.onYenile,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.slate.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isWide ? _buildWideLayout(context) : _buildNarrowLayout(context),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        // Şirket adı + bağlantı modu
        _buildSirketBilgisi(),
        const Spacer(),
        // Son yenilenme
        _buildSonYenilenme(),
        const SizedBox(width: 16),
        // Tarih filtresi
        _buildTarihFiltresi(),
        const SizedBox(width: 8),
        // Yenile butonu
        _buildYenileButonu(),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSirketBilgisi()),
            _buildYenileButonu(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSonYenilenme(),
            const Spacer(),
            _buildTarihFiltresi(),
          ],
        ),
      ],
    );
  }

  Widget _buildSirketBilgisi() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: baglantiModu == 'cloud'
                ? const Color(0xFF4CAF50)
                : const Color(0xFF1E5F74),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            sirketAdi,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppPalette.slate,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: baglantiModu == 'cloud'
                ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                : const Color(0xFF1E5F74).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            baglantiModu == 'cloud'
                ? '☁ Bulut'
                : baglantiModu == 'hybrid'
                    ? '⇄ Karma'
                    : '💻 Yerel',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: baglantiModu == 'cloud'
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF1E5F74),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSonYenilenme() {
    final saat = '${sonYenilenme.hour.toString().padLeft(2, '0')}:'
        '${sonYenilenme.minute.toString().padLeft(2, '0')}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 14,
          color: AppPalette.grey.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          saat,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppPalette.grey.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildTarihFiltresi() {
    const filtreler = [
      ('bugun', 'Bugün'),
      ('buHafta', 'Bu Hafta'),
      ('buAy', 'Bu Ay'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: filtreler.map((f) {
          final isActive = seciliFiltre == f.$1;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onFiltreSecildi(f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1E5F74)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : AppPalette.slate,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildYenileButonu() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onYenile,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1E5F74).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 18,
            color: Color(0xFF1E5F74),
          ),
        ),
      ),
    );
  }
}
