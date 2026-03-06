import 'package:flutter/material.dart';
import '../ayarlar/menu_ayarlari.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';
import '../sayfalar/ayarlar/kullanicilar/modeller/kullanici_model.dart';
import '../sayfalar/ayarlar/sirketayarlari/modeller/sirket_ayarlari_model.dart';
import '../servisler/ayarlar_veritabani_servisi.dart';
import '../servisler/bankalar_veritabani_servisi.dart';
import '../servisler/cekler_veritabani_servisi.dart';
import 'dart:convert';
import '../servisler/kasalar_veritabani_servisi.dart';
import '../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../servisler/oturum_servisi.dart';
import '../servisler/senetler_veritabani_servisi.dart';
import '../sayfalar/giris/giris_sayfasi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../servisler/sayfa_senkronizasyon_servisi.dart';

class YanMenu extends StatefulWidget {
  const YanMenu({
    super.key,
    required this.isExpanded,
    required this.selectedIndex,
    required this.onToggle,
    required this.onItemSelected,
    this.onCompanySwitched,
    required this.currentUser,
    required this.currentCompany,
  });

  final bool isExpanded;
  final int selectedIndex;
  final VoidCallback onToggle;
  final ValueChanged<int> onItemSelected;
  final VoidCallback? onCompanySwitched;
  final KullaniciModel currentUser;
  final SirketAyarlariModel currentCompany;

  @override
  State<YanMenu> createState() => _YanMenuState();
}

class _YanMenuState extends State<YanMenu> {
  final GlobalKey _userMenuKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String? _openedMenuId;
  String? _openedSubMenuId;
  List<String> _userPermissions = [];
  Map<String, bool>? _moduleVisibility;

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
    _fetchModuleVisibility();
    SayfaSenkronizasyonServisi().addListener(_onSyncNotification);
  }

  void _onSyncNotification() {
    _fetchModuleVisibility();
  }

  Future<void> _fetchModuleVisibility() async {
    final ayarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _moduleVisibility = ayarlar.aktifModuller;
      });
    }
  }

  bool _isModuleVisible(String id) {
    if (_moduleVisibility == null) return true;
    return _moduleVisibility![id] ?? true;
  }

  @override
  void dispose() {
    SayfaSenkronizasyonServisi().removeListener(_onSyncNotification);
    _userMenuKey.currentState?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setOpenedMenu(String? id) {
    if (_openedMenuId == id) return;
    if (!mounted) return;
    setState(() {
      _openedMenuId = id;
      _openedSubMenuId = null;
    });
  }

  @override
  void didUpdateWidget(YanMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isExpanded && oldWidget.isExpanded) {
      _setOpenedMenu(null);
      _openedSubMenuId = null;
    }
    if (widget.currentUser.rol != oldWidget.currentUser.rol) {
      _fetchPermissions();
    }
  }

  Future<void> _fetchPermissions() async {
    if (widget.currentUser.rol == 'admin') {
      if (mounted) setState(() => _userPermissions = ['*']);
      return;
    }

    final rol = await AyarlarVeritabaniServisi().rolGetir(
      widget.currentUser.rol,
    );
    if (mounted) {
      setState(() {
        _userPermissions = rol?.izinler ?? [];
      });
    }
  }

  bool _hasPermission(String id) {
    if (widget.currentUser.rol == 'admin') return true;
    if (_userPermissions.contains('*')) return true;
    return _userPermissions.contains(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveExpanded =
            widget.isExpanded && constraints.maxWidth >= 160.0;

        return Container(
          decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: effectiveExpanded
                    ? Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr('nav.app.shortTitle'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              onPressed: widget.onToggle,
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              tooltip: tr('sidebar.collapse'),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
              ),
              Divider(
                height: 1,
                color: const Color(0xFF737373).withValues(alpha: 0.6),
              ),
              Expanded(
                child: RawScrollbar(
                  thumbColor: Colors.white.withValues(alpha: 0.35),
                  radius: const Radius.circular(4),
                  thickness: 6,
                  thumbVisibility: true,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        ...MenuAyarlari.menuItems
                            .where((item) {
                              if (!_isModuleVisible(item.id)) return false;
                              if (_hasPermission(item.id)) return true;
                              return item.children.any(
                                (c) =>
                                    (_isModuleVisible(c.id) &&
                                        _hasPermission(c.id)) ||
                                    c.children.any(
                                      (g) =>
                                          _isModuleVisible(g.id) &&
                                          _hasPermission(g.id),
                                    ),
                              );
                            })
                            .map((item) {
                              if (item.hasChildren) {
                                final isChildSelected = item.children.any(
                                  (c) =>
                                      c.index == widget.selectedIndex ||
                                      c.children.any(
                                        (grand) =>
                                            grand.index == widget.selectedIndex,
                                      ),
                                );
                                final bool shouldOpenBySelection =
                                    _openedMenuId == null && isChildSelected;
                                final bool isOpen =
                                    (_openedMenuId != null &&
                                        _openedMenuId == item.id) ||
                                    shouldOpenBySelection;
                                final showSubmenu = effectiveExpanded && isOpen;

                                return Column(
                                  children: [
                                    YanMenuOgesi(
                                      icon: item.icon,
                                      label: tr(item.labelKey),
                                      isExpanded: effectiveExpanded,
                                      isSelected: isChildSelected,
                                      trailing: effectiveExpanded
                                          ? _buildChevronIcon(isOpen: isOpen)
                                          : null,
                                      onTap: () {
                                        if (effectiveExpanded) {
                                          final nextState =
                                              isOpen && _openedMenuId == item.id
                                              ? null
                                              : item.id;
                                          _setOpenedMenu(nextState);
                                        }
                                      },
                                    ),
                                    if (showSubmenu)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 32,
                                          right: 8,
                                          top: 2,
                                        ),
                                        child: Column(
                                          children: item.children
                                              .where((child) {
                                                if (!_isModuleVisible(
                                                  child.id,
                                                )) {
                                                  return false;
                                                }
                                                if (_hasPermission(child.id)) {
                                                  return true;
                                                }
                                                return child.children.any(
                                                  (g) =>
                                                      _isModuleVisible(g.id) &&
                                                      _hasPermission(g.id),
                                                );
                                              })
                                              .map((child) {
                                                final hasGrandChildren =
                                                    child.hasChildren;
                                                final bool
                                                isGrandChildSelected =
                                                    hasGrandChildren &&
                                                    child.children.any(
                                                      (grand) =>
                                                          grand.index ==
                                                          widget.selectedIndex,
                                                    );

                                                if (hasGrandChildren) {
                                                  final bool
                                                  shouldOpenSubBySelection =
                                                      _openedSubMenuId ==
                                                          null &&
                                                      isGrandChildSelected;
                                                  final bool isSubOpen =
                                                      (_openedSubMenuId !=
                                                              null &&
                                                          _openedSubMenuId ==
                                                              child.id) ||
                                                      shouldOpenSubBySelection;
                                                  final bool showGrandChildren =
                                                      effectiveExpanded &&
                                                      isSubOpen;

                                                  return Column(
                                                    children: [
                                                      AyarlarAltOgesi(
                                                        icon: child.icon,
                                                        label: tr(
                                                          child.labelKey,
                                                        ),
                                                        isActive:
                                                            isGrandChildSelected,
                                                        trailing:
                                                            effectiveExpanded
                                                            ? _buildChevronIcon(
                                                                isOpen:
                                                                    isSubOpen,
                                                              )
                                                            : null,
                                                        onTap: () {
                                                          if (effectiveExpanded) {
                                                            if (mounted) {
                                                              setState(() {
                                                                _openedSubMenuId =
                                                                    isSubOpen &&
                                                                        _openedSubMenuId ==
                                                                            child.id
                                                                    ? null
                                                                    : child.id;
                                                              });
                                                            }
                                                          } else if (child
                                                                  .index !=
                                                              null) {
                                                            widget
                                                                .onItemSelected(
                                                                  child.index!,
                                                                );
                                                          }
                                                        },
                                                      ),
                                                      if (showGrandChildren)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 16,
                                                                right: 4,
                                                              ),
                                                          child: Column(
                                                            children: child
                                                                .children
                                                                .where(
                                                                  (grand) =>
                                                                      _isModuleVisible(
                                                                        grand
                                                                            .id,
                                                                      ) &&
                                                                      _hasPermission(
                                                                        grand
                                                                            .id,
                                                                      ),
                                                                )
                                                                .map((grand) {
                                                                  return AyarlarAltOgesi(
                                                                    icon: grand
                                                                        .icon,
                                                                    label: tr(
                                                                      grand
                                                                          .labelKey,
                                                                    ),
                                                                    isActive:
                                                                        widget
                                                                            .selectedIndex ==
                                                                        grand
                                                                            .index,
                                                                    onTap: () =>
                                                                        widget.onItemSelected(
                                                                          grand
                                                                              .index!,
                                                                        ),
                                                                  );
                                                                })
                                                                .toList(),
                                                          ),
                                                        ),
                                                    ],
                                                  );
                                                }

                                                return AyarlarAltOgesi(
                                                  icon: child.icon,
                                                  label: tr(child.labelKey),
                                                  isActive:
                                                      widget.selectedIndex ==
                                                      child.index,
                                                  onTap: () =>
                                                      widget.onItemSelected(
                                                        child.index!,
                                                      ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                );
                              } else {
                                return YanMenuOgesi(
                                  icon: item.icon,
                                  label: tr(item.labelKey),
                                  isExpanded: effectiveExpanded,
                                  isSelected:
                                      widget.selectedIndex == item.index,
                                  onTap: () {
                                    widget.onItemSelected(item.index!);
                                    if (effectiveExpanded) {
                                      _setOpenedMenu(null);
                                    }
                                  },
                                );
                              }
                            }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              if (effectiveExpanded)
                _buildUserSection(theme, colorScheme)
              else
                _buildCollapsedUserAvatar(colorScheme, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChevronIcon({required bool isOpen}) {
    return AnimatedRotation(
      duration: const Duration(milliseconds: 180),
      turns: isOpen ? 0.5 : 0.0,
      child: Icon(
        Icons.expand_more_rounded,
        size: 18,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildCollapsedUserAvatar(ColorScheme colorScheme, ThemeData theme) {
    final rawName = widget.currentUser.ad.isNotEmpty
        ? '${widget.currentUser.ad} ${widget.currentUser.soyad}'
        : widget.currentUser.kullaniciAdi;
    final avatarText = rawName.isNotEmpty
        ? rawName.substring(0, 1).toUpperCase()
        : 'U';

    ImageProvider? profileImage;
    if (widget.currentUser.profilResmi != null &&
        widget.currentUser.profilResmi!.isNotEmpty) {
      try {
        profileImage = MemoryImage(
          base64Decode(widget.currentUser.profilResmi!),
        );
      } catch (e) {
        debugPrint('Profil resmi yüklenemedi: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.9),
        foregroundColor: colorScheme.primary,
        backgroundImage: profileImage,
        child: profileImage == null
            ? Text(
                avatarText,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildUserSection(ThemeData theme, ColorScheme colorScheme) {
    final rawName = widget.currentUser.ad.isNotEmpty
        ? '${widget.currentUser.ad} ${widget.currentUser.soyad}'
        : widget.currentUser.kullaniciAdi;
    final avatarText = rawName.isNotEmpty
        ? rawName.substring(0, 1).toUpperCase()
        : 'U';
    final companyLabel = widget.currentCompany.ad;

    ImageProvider? profileImage;
    if (widget.currentUser.profilResmi != null &&
        widget.currentUser.profilResmi!.isNotEmpty) {
      try {
        profileImage = MemoryImage(
          base64Decode(widget.currentUser.profilResmi!),
        );
      } catch (e) {
        debugPrint('Profil resmi yüklenemedi: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Material(
        key: _userMenuKey,
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openUserMenu(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.onPrimary.withValues(
                    alpha: 0.92,
                  ),
                  foregroundColor: colorScheme.primary,
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Text(
                          avatarText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rawName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        companyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        OturumServisi().aktifVeritabaniAdi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUserMenu() async {
    final renderBox =
        _userMenuKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + renderBox.size.height,
      overlay.size.width - (offset.dx + renderBox.size.width),
      offset.dy,
    );

    // Şirketleri getir
    List<SirketAyarlariModel> sirketler = [];
    try {
      sirketler = await AyarlarVeritabaniServisi().sirketleriGetir(
        sayfa: 1,
        sayfaBasinaKayit: 100,
      );
    } catch (e) {
      debugPrint('Şirketler yüklenemedi: $e');
    }

    // Değiştirilebilir durumu kontrol et
    final canSwitch = widget.currentCompany.duzenlenebilirMi;

    if (!mounted) return;

    final result = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            tr('settings.company.select_database'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        ...sirketler.where((s) => s.aktifMi).map((s) {
          final isSelected = s.kod == widget.currentCompany.kod;
          return PopupMenuItem<String>(
            value: 'company_${s.kod}',
            enabled: canSwitch || isSelected,
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.business,
                  size: 18,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.ad,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                tr('login.logout'),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );

    if (result == 'logout') {
      // Çıkış Yap
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('beni_hatirla') != true) {
        await prefs.remove('kullanici_adi');
        await prefs.remove('sifre');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const GirisSayfasi()),
          (route) => false,
        );
      }
    } else if (result != null && result.toString().startsWith('company_')) {
      final companyCode = result.toString().substring(8);

      // Eğer zaten seçili şirketse işlem yapma
      if (companyCode == widget.currentCompany.kod) return;

      // Değiştirilebilir değilse işlem yapma (UI'da disabled olsa bile güvenlik için)
      if (!canSwitch) return;

      final selectedCompany = sirketler.firstWhere((s) => s.kod == companyCode);

      // Oturumu Güncelle
      OturumServisi().aktifSirket = selectedCompany;

      await KasalarVeritabaniServisi().baslat();
      await BankalarVeritabaniServisi().baslat();
      await KrediKartlariVeritabaniServisi().baslat();
      await CeklerVeritabaniServisi().baslat();
      await SenetlerVeritabaniServisi().baslat();

      if (!mounted) return;

      // Callback'i tetikle
      if (widget.onCompanySwitched != null) {
        widget.onCompanySwitched!();
      }
    }
  }
}

class AyarlarAltOgesi extends StatelessWidget {
  const AyarlarAltOgesi({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: (theme.textTheme.labelMedium?.fontSize ?? 12),
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                      fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class YanMenuOgesi extends StatefulWidget {
  const YanMenuOgesi({
    super.key,
    required this.icon,
    required this.label,
    required this.isExpanded,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<YanMenuOgesi> createState() => _YanMenuOgesiState();
}

class _YanMenuOgesiState extends State<YanMenuOgesi> {
  bool _isHovered = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    if (!mounted) return;
    setState(() {
      _isHovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool isActive = widget.isSelected || _isHovered;
    final bgColor = isActive
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.transparent;
    final fgColor = isActive
        ? Colors.white
        : Colors.white.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isExpanded ? 14 : 0,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: widget.isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 20, color: fgColor),
                  if (widget.isExpanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize:
                              (theme.textTheme.labelLarge?.fontSize ?? 14) *
                              0.95,
                          color: fgColor,
                          fontWeight: isActive
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
