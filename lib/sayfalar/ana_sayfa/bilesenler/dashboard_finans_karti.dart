import 'package:flutter/material.dart';
import '../../../temalar/app_theme.dart';

/// Orta Bant Finansal Kart — tek verilik kompakt kart.
/// Kredi Kartı, Çek, Senet, Sipariş, Teklif, Gider gibi verileri gösterir.
class DashboardFinansKarti extends StatefulWidget {
  final String baslik;
  final String deger;
  final IconData ikon;
  final Color renk;
  final VoidCallback? onTap;
  final bool adetMi; // tutar yerine adet gösterecekse true

  const DashboardFinansKarti({
    super.key,
    required this.baslik,
    required this.deger,
    required this.ikon,
    required this.renk,
    this.onTap,
    this.adetMi = false,
  });

  @override
  State<DashboardFinansKarti> createState() => _DashboardFinansKartiState();
}

class _DashboardFinansKartiState extends State<DashboardFinansKarti> {
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
          curve: Curves.easeOutCubic,
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.02, 1.02, 1)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(16),
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
                    ? widget.renk.withValues(alpha: 0.1)
                    : AppPalette.slate.withValues(alpha: 0.06),
                blurRadius: _isHovered ? 16 : 10,
                offset: const Offset(0, 3),
                spreadRadius: _isHovered ? 1 : 0,
              ),
              BoxShadow(
                color: AppPalette.slate.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.renk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.ikon, color: widget.renk, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.baslik,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: AppPalette.grey.withValues(alpha: 0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.deger,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: AppPalette.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppPalette.grey.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
