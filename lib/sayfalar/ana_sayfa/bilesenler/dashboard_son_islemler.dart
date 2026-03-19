import 'package:flutter/material.dart';
import '../../../temalar/app_theme.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../modeller/dashboard_ozet_modeli.dart';

/// Dashboard Son İşlemler Akışı
/// Son 15 hareket tek zaman çizgisinde gösterilir.
class DashboardSonIslemler extends StatefulWidget {
  final List<SonIslem> islemler;
  final void Function(int menuIndex) onIslemTap;

  const DashboardSonIslemler({
    super.key,
    required this.islemler,
    required this.onIslemTap,
  });

  @override
  State<DashboardSonIslemler> createState() => _DashboardSonIslemlerState();
}

class _DashboardSonIslemlerState extends State<DashboardSonIslemler> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered
            ? Matrix4.diagonal3Values(1.005, 1.005, 1)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: AppPalette.slate.withValues(alpha: 0.06),
              blurRadius: 12,
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
                    color: AppPalette.slate.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: AppPalette.slate,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Son İşlemler',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppPalette.slate,
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => widget.onIslemTap(12),
                    child: Text(
                      'Tümünü Gör →',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E5F74).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // İşlem listesi
            if (widget.islemler.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Henüz işlem yok',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppPalette.grey.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else
              ...widget.islemler
                  .take(15)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => _buildIslemItem(
                      entry.value,
                      isLast:
                          entry.key == widget.islemler.length - 1 ||
                          entry.key == 14,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildIslemItem(SonIslem islem, {bool isLast = false}) {
    final config = _islemConfig(islem.tur);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onIslemTap(config.menuIndex),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zaman çizgisi
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: config.renk.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(config.ikon, size: 16, color: config.renk),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: AppPalette.grey.withValues(alpha: 0.15),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // İçerik
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: config.renk.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    config.etiket,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: config.renk,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    islem.cariAdi,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppPalette.slate,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              islem.aciklama,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppPalette.grey.withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${config.isGiris ? '+' : '-'}${FormatYardimcisi.sayiFormatlaOndalikli(islem.tutar)} ₺',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: config.isGiris
                                  ? const Color(0xFF27AE60)
                                  : AppPalette.red,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _zamanFormatla(islem.tarih),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppPalette.grey.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _zamanFormatla(DateTime tarih) {
    final simdi = DateTime.now();
    final fark = simdi.difference(tarih);

    if (fark.inMinutes < 1) return 'şimdi';
    if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
    if (fark.inHours < 24) return '${fark.inHours} sa önce';
    if (fark.inDays < 7) return '${fark.inDays} gün önce';
    return '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}';
  }

  _IslemConfig _islemConfig(String tur) {
    switch (tur) {
      case 'satis':
        return const _IslemConfig(
          etiket: 'Satış',
          ikon: Icons.north_east_rounded,
          renk: Color(0xFF27AE60),
          isGiris: true,
          menuIndex: 12,
        );
      case 'tahsilat':
        return const _IslemConfig(
          etiket: 'Tahsilat',
          ikon: Icons.north_east_rounded,
          renk: Color(0xFF27AE60),
          isGiris: true,
          menuIndex: 13,
        );
      case 'alis':
        return const _IslemConfig(
          etiket: 'Alış',
          ikon: Icons.south_west_rounded,
          renk: AppPalette.red,
          isGiris: false,
          menuIndex: 12,
        );
      case 'odeme':
        return const _IslemConfig(
          etiket: 'Ödeme',
          ikon: Icons.south_west_rounded,
          renk: AppPalette.red,
          isGiris: false,
          menuIndex: 13,
        );
      case 'cek':
        return const _IslemConfig(
          etiket: 'Çek',
          ikon: Icons.description_outlined,
          renk: Color(0xFF2196F3),
          isGiris: true,
          menuIndex: 14,
        );
      case 'senet':
        return const _IslemConfig(
          etiket: 'Senet',
          ikon: Icons.article_outlined,
          renk: Color(0xFFFF9800),
          isGiris: false,
          menuIndex: 17,
        );
      default:
        return const _IslemConfig(
          etiket: 'İşlem',
          ikon: Icons.swap_horiz_rounded,
          renk: AppPalette.grey,
          isGiris: true,
          menuIndex: 12,
        );
    }
  }
}

class _IslemConfig {
  final String etiket;
  final IconData ikon;
  final Color renk;
  final bool isGiris;
  final int menuIndex;

  const _IslemConfig({
    required this.etiket,
    required this.ikon,
    required this.renk,
    required this.isGiris,
    required this.menuIndex,
  });
}
