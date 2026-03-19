import 'package:flutter/material.dart';
import '../../../temalar/app_theme.dart';

/// Hızlı İşlem Butonu
class _HizliIslemItem {
  final String baslik;
  final IconData ikon;
  final int menuIndex;

  const _HizliIslemItem({
    required this.baslik,
    required this.ikon,
    required this.menuIndex,
  });
}

/// Dashboard Hızlı İşlemler Bölümü
/// Simgeler soluk gelir, hover ile renklenir (Color(0xFF1E5F74)).
class DashboardHizliIslemler extends StatelessWidget {
  final void Function(int menuIndex) onIslemTap;

  const DashboardHizliIslemler({super.key, required this.onIslemTap});

  static const _islemler = <_HizliIslemItem>[
    _HizliIslemItem(
      baslik: 'Hızlı Satış',
      ikon: Icons.flash_on_rounded,
      menuIndex: 23,
    ),
    _HizliIslemItem(
      baslik: 'Satış Yap',
      ikon: Icons.shopping_cart_checkout_rounded,
      menuIndex: 11,
    ),
    _HizliIslemItem(
      baslik: 'Alış Yap',
      ikon: Icons.add_shopping_cart_rounded,
      menuIndex: 10,
    ),
    _HizliIslemItem(
      baslik: 'Yeni Sipariş',
      ikon: Icons.receipt_long_rounded,
      menuIndex: 18,
    ),
    _HizliIslemItem(
      baslik: 'Yeni Ürün',
      ikon: Icons.inventory_2_outlined,
      menuIndex: 7,
    ),
    _HizliIslemItem(
      baslik: 'Tahsilat / Ödeme',
      ikon: Icons.account_balance_wallet_outlined,
      menuIndex: 13,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  Icons.bolt_rounded,
                  color: Color(0xFF1E5F74),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Hızlı İşlemler',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppPalette.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                // Mobil: 3x2 grid
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _islemler.map((item) {
                    return SizedBox(
                      width: (constraints.maxWidth - 20) / 3,
                      child: _HizliIslemButonu(
                        item: item,
                        onTap: () => onIslemTap(item.menuIndex),
                        compact: true,
                      ),
                    );
                  }).toList(),
                );
              }
              // Masaüstü: yatay
              return Row(
                children: _islemler.map((item) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _HizliIslemButonu(
                        item: item,
                        onTap: () => onIslemTap(item.menuIndex),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tekil hızlı işlem butonu
class _HizliIslemButonu extends StatefulWidget {
  final _HizliIslemItem item;
  final VoidCallback onTap;
  final bool compact;

  const _HizliIslemButonu({
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_HizliIslemButonu> createState() => _HizliIslemButonuState();
}

class _HizliIslemButonuState extends State<_HizliIslemButonu> {
  bool _isHovered = false;

  static const _activeColor = Color(0xFF1E5F74);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: widget.compact ? 12 : 14,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? _activeColor.withValues(alpha: 0.06)
                : AppPalette.grey.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? _activeColor.withValues(alpha: 0.25)
                  : AppPalette.grey.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.item.ikon,
                  size: widget.compact ? 22 : 26,
                  color: _isHovered
                      ? _activeColor
                      : AppPalette.grey.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.baslik,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: widget.compact ? 10 : 11,
                  fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w500,
                  color: _isHovered ? _activeColor : AppPalette.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
