import 'package:flutter/material.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

/// Tab verisi modeli
class TabVeri {
  final String id;
  final String baslik;
  final String? baslikKey;
  final String Function()? baslikOlusturucu;
  final IconData ikon;
  final int menuIndex;
  final Widget Function() sayfaOlusturucu;

  const TabVeri({
    required this.id,
    required this.baslik,
    this.baslikKey,
    this.baslikOlusturucu,
    required this.ikon,
    required this.menuIndex,
    required this.sayfaOlusturucu,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabVeri && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Tab yöneticisi widget'ı - Ultra Stabil ve Profesyonel
class TabYonetici extends StatefulWidget {
  const TabYonetici({
    super.key,
    required this.acikTablar,
    required this.aktifTabIndex,
    required this.onTabSecildi,
    required this.onTabKapatildi,
    required this.onTumunuKapat,
    required this.refreshKey,
  });

  final List<TabVeri> acikTablar;
  final int aktifTabIndex;
  final ValueChanged<int> onTabSecildi;
  final ValueChanged<int> onTabKapatildi;
  final VoidCallback onTumunuKapat;
  final int refreshKey;

  @override
  State<TabYonetici> createState() => _TabYoneticiState();
}

class _TabYoneticiState extends State<TabYonetici> {
  final ScrollController _scrollController = ScrollController();
  int? _hoveredTabIndex;
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // İlk render sonrası okları kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollListener());
  }

  @override
  void didUpdateWidget(TabYonetici oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Yeni tab eklendiyse veya aktif tab değiştiyse kontrol et
    if (widget.acikTablar.length > oldWidget.acikTablar.length ||
        widget.aktifTabIndex != oldWidget.aktifTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Bir sonraki frame'de layout'un güncellenmiş olması için küçük bir gecikme
          Future.delayed(const Duration(milliseconds: 50), () {
            if (!mounted) return;
            // Yeni tab eklendiyse en sona, aksi halde seçilen taba kaydır
            if (widget.acikTablar.length > oldWidget.acikTablar.length) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            } else {
              _scrollToActiveTab(widget.aktifTabIndex);
            }
          });
        }
      });
    }
    // Okları kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollListener());
  }

  void _scrollToActiveTab(int index) {
    if (!_scrollController.hasClients) return;
    // Tab genişliği 180 + separator 4
    double targetOffset = index * 184.0;
    double viewportWidth = _scrollController.position.viewportDimension;

    if (targetOffset < _scrollController.offset ||
        targetOffset > (_scrollController.offset + viewportWidth - 184)) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final bool showLeft = _scrollController.offset > 10;
    final bool showRight =
        _scrollController.offset <
        (_scrollController.position.maxScrollExtent - 10);

    if (showLeft != _showLeftArrow || showRight != _showRightArrow) {
      if (mounted) {
        setState(() {
          _showLeftArrow = showLeft;
          _showRightArrow = showRight;
        });
      }
    }
  }

  void _scrollToLeft() {
    _scrollController.animateTo(
      (_scrollController.offset - 250).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToRight() {
    _scrollController.animateTo(
      (_scrollController.offset + 250).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.acikTablar.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: CeviriServisi(),
      builder: (context, child) {
        return Container(
          height: 44,
          width: double.infinity,
          color: const Color(0xFFF1F5F9), // Slate-100
          child: Stack(
            children: [
              // Alt çizgi
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: const Color(0xFFE2E8F0)),
              ),

              // Liste Layer
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: 48, // Çıkış butonu için alan
                    left: 0,
                  ),
                  child: ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.acikTablar.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 4),
                    itemBuilder: (context, index) => _buildTab(index),
                  ),
                ),
              ),

              // Sol Overlay & Ok
              if (_showLeftArrow)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 1,
                  child: _buildArrowOverlay(
                    icon: Icons.chevron_left_rounded,
                    onPressed: _scrollToLeft,
                    isLeft: true,
                  ),
                ),

              // Sağ Overlay & Ok
              if (_showRightArrow)
                Positioned(
                  right: 48, // Kapatma butonu öncesi
                  top: 0,
                  bottom: 1,
                  child: _buildArrowOverlay(
                    icon: Icons.chevron_right_rounded,
                    onPressed: _scrollToRight,
                    isLeft: false,
                  ),
                ),

              // En Sağ Kapatma Butonu (Sabit)
              Positioned(
                right: 0,
                top: 0,
                bottom: 1,
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    border: Border(
                      left: BorderSide(color: const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: _CloseAllButton(onPressed: widget.onTumunuKapat),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArrowOverlay({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isLeft,
  }) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            const Color(0xFFF1F5F9),
            const Color(0xFFF1F5F9).withValues(alpha: 0.9),
            const Color(0xFFF1F5F9).withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Align(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(left: isLeft ? 4 : 0, right: isLeft ? 0 : 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab = widget.acikTablar[index];
    final isAktif = index == widget.aktifTabIndex;
    final isHovered = _hoveredTabIndex == index;
    final baslik =
        tab.baslikOlusturucu?.call() ??
        (tab.baslikKey != null ? tr(tab.baslikKey!) : tab.baslik);

    // Renkler
    final bgColor = isAktif
        ? Colors.white
        : (isHovered
              ? const Color(0xFFE2E8F0).withValues(alpha: 0.5)
              : Colors.transparent);
    final borderColor = const Color(0xFFE2E8F0);
    final textColor = isAktif
        ? const Color(0xFF1E293B)
        : const Color(0xFF64748B);
    final iconColor = isAktif
        ? const Color(0xFF3B82F6)
        : const Color(0xFF94A3B8);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTabIndex = index),
      onExit: (_) => setState(() => _hoveredTabIndex = null),
      cursor: SystemMouseCursors.click,
      child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
        onTap: () => widget.onTabSecildi(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 180,
          margin: const EdgeInsets.only(top: 6), // Üstten biraz boşluk
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: isAktif
                ? Border(
                    top: BorderSide(color: borderColor),
                    left: BorderSide(color: borderColor),
                    right: BorderSide(color: borderColor),
                    bottom: BorderSide.none,
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isAktif)
                Positioned(
                  bottom: -1,
                  left: 0,
                  right: 0,
                  height: 2,
                  child: Container(color: Colors.white),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(tab.ikon, size: 16, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isAktif
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _CloseButton(
                      onPressed: () => widget.onTabKapatildi(index),
                      isActive: isAktif,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

class _CloseAllButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CloseAllButton({required this.onPressed});

  @override
  State<_CloseAllButton> createState() => _CloseAllButtonState();
}

class _CloseAllButtonState extends State<_CloseAllButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: tr('tabs.close_all'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isHovered
                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.layers_clear_rounded,
                size: 20,
                color: _isHovered
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const _CloseButton({required this.onPressed, required this.isActive});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovered
                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Icon(
            Icons.close_rounded,
            size: 14,
            color: _isHovered
                ? const Color(0xFFEF4444)
                : (widget.isActive
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFFCBD5E1)),
          ),
        ),
      )),
    );
  }
}

/// Tab içeriği widget'ı - Performans ve Akıllı Cache Sistemi
class TabIcerik extends StatefulWidget {
  const TabIcerik({
    super.key,
    required this.acikTablar,
    required this.aktifTabIndex,
    required this.refreshKey,
  });

  final List<TabVeri> acikTablar;
  final int aktifTabIndex;
  final int refreshKey;

  @override
  State<TabIcerik> createState() => _TabIcerikState();
}

class _TabIcerikState extends State<TabIcerik> {
  // Her tab ID'si için sadece bir widget ve o widget'ı oluşturan tab nesnesini tutuyoruz.
  // Tab nesnesi değişirse (kapatılıp açılırsa) widget da yenilenir.
  final Map<String, _TabCacheItem> _cache = {};

  @override
  void didUpdateWidget(TabIcerik oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Eğer bir tab kapatıldıysa (tab sayısı azaldıysa), tüm tabları resetle
    if (widget.acikTablar.length < oldWidget.acikTablar.length) {
      _cache.clear();
    } else {
      // Sadece kapatılanları temizle (normal durumda zaten yukarıdaki kontrol yakalar ama garanti olsun)
      final aktifIds = widget.acikTablar.map((t) => t.id).toSet();
      _cache.removeWhere((id, _) => !aktifIds.contains(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.acikTablar.isEmpty ||
        widget.aktifTabIndex < 0 ||
        widget.aktifTabIndex >= widget.acikTablar.length) {
      return _buildBosEkran();
    }

    final aktifTab = widget.acikTablar[widget.aktifTabIndex];
    final String id = aktifTab.id;

    // Cache kontrolü:
    // 1. Bu ID ile bir cache var mı?
    // 2. Cache'deki tab nesnesi ile şimdiki nesne aynı mı? (Referans kontrolü)
    // 3. Global refresh key değişti mi?
    final bool needsNewWidget =
        !_cache.containsKey(id) ||
        !identical(_cache[id]!.tabInstance, aktifTab) ||
        _cache[id]!.refreshKey != widget.refreshKey;

    if (needsNewWidget) {
      _cache[id] = _TabCacheItem(
        tabInstance: aktifTab,
        widget: aktifTab.sayfaOlusturucu(),
        refreshKey: widget.refreshKey,
      );
    }

    return KeyedSubtree(
      // Key'e refreshKey ekleyerek Flutter'ın widget tree'yi resetlemesini sağlıyoruz
      key: ValueKey<String>('${id}_${widget.refreshKey}'),
      child: _cache[id]!.widget,
    );
  }

  Widget _buildBosEkran() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                size: 48,
                color: Colors.blueGrey.shade200,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('tabs.no_open_tabs'),
              style: TextStyle(
                fontSize: 18,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('tabs.select_from_menu'),
              style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCacheItem {
  final TabVeri tabInstance;
  final Widget widget;
  final int refreshKey;

  _TabCacheItem({
    required this.tabInstance,
    required this.widget,
    required this.refreshKey,
  });
}
