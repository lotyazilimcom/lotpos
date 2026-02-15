import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../../yardimcilar/responsive_yardimcisi.dart';
import '../../../../bilesenler/standart_tablo.dart';
import '../../../../bilesenler/onay_dialog.dart';
import 'modeller/sirket_ayarlari_model.dart';
import 'veri_kaynagi/sirket_ayarlari_veri_kaynagi.dart';
import 'sirket_ekle_dialog.dart';

import '../../../../servisler/ayarlar_veritabani_servisi.dart';

import '../../ortak/print_preview_screen.dart';

class SirketAyarlariSayfasi extends StatefulWidget {
  const SirketAyarlariSayfasi({super.key});

  @override
  State<SirketAyarlariSayfasi> createState() => _SirketAyarlariSayfasiState();
}

class _SirketAyarlariSayfasiState extends State<SirketAyarlariSayfasi> {
  late SirketAyarlariVeriKaynagi _veriKaynagi;
  List<SirketAyarlariModel> _sirketler = [];
  int _toplamKayitSayisi = 0;
  int _suAnkiSayfa = 1;
  int _sayfaBasinaKayit = 25;
  String _aramaTerimi = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isMobileToolbarExpanded = false;

  @override
  void initState() {
    super.initState();
    _veriKaynagi = SirketAyarlariVeriKaynagi(
      context: context,
      onEdit: _sirketDuzenle,
      onDelete: _sirketSil,
      onStatusChange: _sirketDurumDegistir,
      onSetDefault: _varsayilanYap,
    );
    _searchController.addListener(() {
      if (_searchController.text != _aramaTerimi) {
        _aramaYap(_searchController.text);
      }
    });
    _verileriYukle();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    try {
      final service = AyarlarVeritabaniServisi();

      final toplamSayi = await service.sirketSayisiGetir(
        aramaTerimi: _aramaTerimi,
      );

      final veri = await service.sirketleriGetir(
        sayfa: _suAnkiSayfa,
        sayfaBasinaKayit: _sayfaBasinaKayit,
        aramaTerimi: _aramaTerimi,
      );

      if (mounted) {
        setState(() {
          _sirketler = veri;
          _toplamKayitSayisi = toplamSayi;
        });
        _veriKaynagi.updateData(_sirketler);
      }
    } catch (e) {
      debugPrint('Şirketler yüklenirken hata: $e');
    }
  }

  void _aramaYap(String query) {
    setState(() {
      _aramaTerimi = query;
      _suAnkiSayfa = 1;
    });
    _veriKaynagi.selectAll(false);
    _verileriYukle();
  }

  void _sayfaDegisti(int sayfa, int sayfaBasinaKayit) {
    setState(() {
      _suAnkiSayfa = sayfa;
      _sayfaBasinaKayit = sayfaBasinaKayit;
    });
    _veriKaynagi.selectAll(false);
    _verileriYukle();
  }

  Future<void> _sirketEkle() async {
    final yeniSirket = await showDialog<SirketAyarlariModel>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => const SirketEkleDialog(),
    );

    if (yeniSirket != null) {
      try {
        // 1. Şirketi Ayarlar DB'ye ekle
        await AyarlarVeritabaniServisi().sirketEkle(yeniSirket);

        // 2. Yeni Şirket için Veritabanı Oluştur
        await AyarlarVeritabaniServisi().sirketVeritabaniOlustur(
          yeniSirket.kod,
        );

        await _verileriYukle();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('settings.company.add.success'))),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('common.error.generic')} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sirketDuzenle(SirketAyarlariModel sirket) async {
    final guncelSirket = await showDialog<SirketAyarlariModel>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => SirketEkleDialog(duzenlenecekSirket: sirket),
    );

    if (guncelSirket != null) {
      await AyarlarVeritabaniServisi().sirketGuncelle(guncelSirket);
      await _verileriYukle();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('settings.company.update.success'))),
      );
    }
  }

  Future<void> _sirketSil(SirketAyarlariModel sirket) async {
    if (sirket.id == null) return;
    await AyarlarVeritabaniServisi().sirketSil(sirket.id!);
    await _verileriYukle();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'settings.company.delete.success.single',
            ).replaceAll('{name}', sirket.ad),
          ),
        ),
      );
    }
  }

  Future<void> _sirketDurumDegistir(
    SirketAyarlariModel sirket,
    bool isActive,
  ) async {
    final updated = SirketAyarlariModel(
      id: sirket.id,
      kod: sirket.kod,
      ad: sirket.ad,
      basliklar: sirket.basliklar,
      logolar: sirket.logolar,
      adres: sirket.adres,
      vergiDairesi: sirket.vergiDairesi,
      vergiNo: sirket.vergiNo,
      telefon: sirket.telefon,
      eposta: sirket.eposta,
      webAdresi: sirket.webAdresi,
      aktifMi: isActive,
      varsayilanMi: sirket.varsayilanMi,
      duzenlenebilirMi: sirket.duzenlenebilirMi,
      ustBilgiLogosu: sirket.ustBilgiLogosu,
      ustBilgiSatirlari: sirket.ustBilgiSatirlari,
    );
    await AyarlarVeritabaniServisi().sirketGuncelle(updated);
    await _verileriYukle();
  }

  Future<void> _varsayilanYap(SirketAyarlariModel sirket) async {
    if (sirket.id == null) return;
    await AyarlarVeritabaniServisi().varsayilanSirketYap(sirket.id!);
    await _verileriYukle();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'settings.company.set_default.success',
            ).replaceAll('{name}', sirket.ad),
          ),
        ),
      );
    }
  }

  Future<void> _secilenSirketleriSil() async {
    final secilenIdler = _veriKaynagi.selectedIds;
    final secilenSirketler = _sirketler
        .where((s) => secilenIdler.contains(s.id))
        .toList();

    if (secilenSirketler.any((s) => s.varsayilanMi)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.company.delete.protected.message')),
        ),
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => OnayDialog(
        baslik: tr('settings.company.delete.dialog.title.multi'),
        mesaj: tr(
          'settings.company.delete.dialog.message.multi',
        ).replaceAll('{count}', secilenSirketler.length.toString()),
        onayButonMetni: tr('common.delete'),
        iptalButonMetni: tr('common.cancel'),
        isDestructive: true,
        onOnay: () {},
      ),
    );

    if (onay == true && mounted) {
      for (final sirket in secilenSirketler) {
        if (sirket.id != null) {
          await AyarlarVeritabaniServisi().sirketSil(sirket.id!);
        }
      }
      _veriKaynagi.selectAll(false);
      await _verileriYukle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'settings.company.delete.success.multi',
              ).replaceAll('{count}', secilenSirketler.length.toString()),
            ),
          ),
        );
      }
    }
  }

  void _handlePrint() {
    final headers = [
      tr('settings.company.code.label'),
      tr('settings.company.name.label'),
      tr('settings.company.column.default'),
      tr('settings.company.column.status'),
    ];

    final data = _sirketler.map((sirket) {
      return [
        sirket.kod,
        sirket.ad,
        sirket.varsayilanMi ? tr('common.yes') : tr('common.no'),
        sirket.aktifMi ? tr('common.active') : tr('common.passive'),
      ];
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          title: tr('settings.company.title'),
          headers: headers,
          data: data,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
    double height = 40,
    double iconSize = 16,
    double fontSize = 12,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8),
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSquareActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
    required Color borderColor,
    required String tooltip,
    double size = 40,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTopActionRow() {
    final double width = MediaQuery.of(context).size.width;
    final bool isNarrow = width < 360;

    final String addLabel = isNarrow
        ? tr('common.add')
        : tr('settings.company.add');
    final bool hasSelection = _veriKaynagi.selectedCount > 0;
    final String printTooltip = hasSelection
        ? tr('common.print_selected')
        : tr('common.print_list');

    return Row(
      children: [
        Expanded(
          child: _buildMobileActionButton(
            label: addLabel,
            icon: Icons.add,
            color: const Color(0xFFEA4335),
            textColor: Colors.white,
            borderColor: Colors.transparent,
            onTap: _sirketEkle,
            height: 40,
            iconSize: 16,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const SizedBox(width: 8),
        _buildMobileSquareActionButton(
          icon: Icons.print_outlined,
          onTap: _handlePrint,
          color: const Color(0xFFF8F9FA),
          iconColor: Colors.black87,
          borderColor: Colors.grey.shade300,
          tooltip: printTooltip,
          size: 40,
        ),
      ],
    );
  }

  Widget _buildMobileToolbarCard({
    required int totalRecords,
    required double maxExpandedHeight,
  }) {
    final int activeFilterCount = _aramaTerimi.trim().isNotEmpty ? 1 : 0;
    final bool hasSelection = _veriKaynagi.selectedCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _isMobileToolbarExpanded = !_isMobileToolbarExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact = constraints.maxWidth < 330;
                  final String toggleLabel = compact
                      ? (_isMobileToolbarExpanded ? 'Gizle' : 'Göster')
                      : (_isMobileToolbarExpanded
                            ? 'Filtreleri Gizle'
                            : 'Filtreleri Göster');

                  return Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2C3E50,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalRecords kayıt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeFilterCount == 0
                                  ? 'Filtre yok'
                                  : '$activeFilterCount filtre aktif',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        toggleLabel,
                        style: const TextStyle(
                          color: Color(0xFF2C3E50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isMobileToolbarExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            child: !_isMobileToolbarExpanded
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Divider(height: 1, color: Colors.grey.shade200),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxExpandedHeight,
                        ),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _sayfaBasinaKayit,
                                        items: [10, 25, 50, 100]
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e.toString()),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val == null) return;
                                          _sayfaDegisti(1, val);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        hintText: tr(
                                          'settings.general.search.placeholder',
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Colors.grey,
                                        ),
                                        border: const UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        enabledBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.grey,
                                              ),
                                            ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFF2C3E50),
                                              ),
                                            ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                        filled: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasSelection)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Builder(
                                      builder: (context) {
                                        final bool isDisabled =
                                            _veriKaynagi.hasCoreCompanySelected;
                                        return MouseRegion(
                                          cursor: isDisabled
                                              ? SystemMouseCursors.forbidden
                                              : SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: isDisabled
                                                ? null
                                                : () => _secilenSirketleriSil(),
                                            child: Opacity(
                                              opacity: isDisabled ? 0.5 : 1.0,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEA4335,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.delete_outline,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      tr(
                                                        'common.delete_selected',
                                                      ).replaceAll(
                                                        '{count}',
                                                        _veriKaynagi
                                                            .selectedCount
                                                            .toString(),
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool forceMobile = ResponsiveYardimcisi.tabletMi(context);
          if (forceMobile || constraints.maxWidth < 800) {
            return _buildMobileView();
          } else {
            return _buildDesktopView();
          }
        },
      ),
    );
  }

  Widget _buildDesktopView() {
    return StandartTablo(
      title: tr('settings.company.title'),
      source: _veriKaynagi,
      columns: _buildColumns(),
      onSearch: _aramaYap,
      onPageChanged: _sayfaDegisti,
      totalRecords: _toplamKayitSayisi,
      persistenceKey: 'sirket_ayarlari',
      selectionWidget: AnimatedBuilder(
        animation: _veriKaynagi,
        builder: (context, child) {
          if (_veriKaynagi.selectedCount > 0) {
            final bool isDisabled = _veriKaynagi.hasCoreCompanySelected;
            return MouseRegion(
              cursor: isDisabled
                  ? SystemMouseCursors.forbidden
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: isDisabled ? null : () => _secilenSirketleriSil(),
                child: Opacity(
                  opacity: isDisabled ? 0.5 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA4335),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tr('common.delete_selected').replaceAll(
                            '{count}',
                            _veriKaynagi.selectedCount.toString(),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      actions: [
        _buildActionButton(
          label: tr('common.print_list'),
          icon: Icons.print_outlined,
          color: const Color(0xFFF8F9FA),
          textColor: Colors.black87,
          borderColor: Colors.grey.shade300,
          onTap: _handlePrint,
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _sirketEkle,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEA4335),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    tr('settings.company.add'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    final mediaQuery = MediaQuery.of(context);
    final bool isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final int totalPages = _toplamKayitSayisi == 0
        ? 1
        : (_toplamKayitSayisi / _sayfaBasinaKayit).ceil();
    final int effectivePage = _suAnkiSayfa.clamp(1, totalPages);
    if (effectivePage != _suAnkiSayfa) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _suAnkiSayfa = effectivePage);
      });
    }
    final int showingStart = _toplamKayitSayisi == 0
        ? 0
        : ((effectivePage - 1) * _sayfaBasinaKayit + 1);
    final int showingEnd = (effectivePage * _sayfaBasinaKayit).clamp(
      0,
      _toplamKayitSayisi,
    );
    final double availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.bottom;
    final double maxExpandedHeight = (availableHeight * 0.5).clamp(
      180.0,
      420.0,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    tr('settings.company.title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AnimatedBuilder(
                animation: _veriKaynagi,
                builder: (context, child) {
                  return _buildMobileToolbarCard(
                    totalRecords: _toplamKayitSayisi,
                    maxExpandedHeight: maxExpandedHeight,
                  );
                },
              ),
            ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AnimatedBuilder(
                  animation: _veriKaynagi,
                  builder: (context, child) => _buildMobileTopActionRow(),
                ),
              ),
            Expanded(
              child: _sirketler.isEmpty
                  ? Center(
                      child: Text(
                        tr('common.no_data'),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _sirketler.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildCompanyCard(_sirketler[index]);
                      },
                    ),
            ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: effectivePage > 1
                          ? () => _sayfaDegisti(
                              effectivePage - 1,
                              _sayfaBasinaKayit,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        tr('common.pagination.showing')
                            .replaceAll('{start}', showingStart.toString())
                            .replaceAll('{end}', showingEnd.toString())
                            .replaceAll(
                              '{total}',
                              _toplamKayitSayisi.toString(),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: effectivePage < totalPages
                          ? () => _sayfaDegisti(
                              effectivePage + 1,
                              _sayfaBasinaKayit,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(SirketAyarlariModel sirket) {
    return AnimatedBuilder(
      animation: _veriKaynagi,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _veriKaynagi.isSelected(sirket.id),
                      onChanged: (v) {
                        _veriKaynagi.toggleSelection(sirket.id);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(color: Color(0xFFD1D1D1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sirket.ad,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sirket.kod} • ${tr('common.id')} ${sirket.id}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildPopupMenu(sirket),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sirket.aktifMi
                              ? const Color(0xFFE6F4EA)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sirket.aktifMi
                              ? tr('common.active')
                              : tr('common.passive'),
                          style: TextStyle(
                            color: sirket.aktifMi
                                ? const Color(0xFF1E7E34)
                                : const Color(0xFF757575),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),

              // Middle Row (Default Toggle)
              Row(
                children: [
                  Text(
                    sirket.varsayilanMi
                        ? tr('settings.company.column.default')
                        : tr('settings.company.set_default'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sirket.varsayilanMi
                          ? const Color(0xFF1E7E34)
                          : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  _CustomSwitch(
                    value: sirket.varsayilanMi,
                    onChanged: sirket.varsayilanMi
                        ? null
                        : (val) {
                            if (val) {
                              _varsayilanYap(sirket);
                            }
                          },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bottom Row (Buttons)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _sirketDuzenle(sirket),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2C3E50)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        tr('common.edit'),
                        style: const TextStyle(
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopupMenu(SirketAyarlariModel sirket) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: const Icon(Icons.more_horiz, color: Colors.black54, size: 20),
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 190),
        splashRadius: 20,
        offset: const Offset(0, 8),
        tooltip: tr('settings.company.column.actions'),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'edit',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.edit'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: sirket.aktifMi ? 'deactivate' : 'activate',
            enabled: !sirket.varsayilanMi,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  sirket.aktifMi
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  size: 20,
                  color: sirket.varsayilanMi
                      ? Colors.grey.shade400
                      : const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  sirket.aktifMi
                      ? tr('common.deactivate')
                      : tr('common.activate'),
                  style: TextStyle(
                    color: sirket.varsayilanMi
                        ? Colors.grey.shade400
                        : const Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            enabled: !sirket.varsayilanMi,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: sirket.varsayilanMi
                      ? Colors.grey.shade400
                      : const Color(0xFFEA4335),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.delete'),
                  style: TextStyle(
                    color: sirket.varsayilanMi
                        ? Colors.grey.shade400
                        : const Color(0xFFEA4335),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            _sirketDuzenle(sirket);
          } else if (value == 'deactivate') {
            _sirketDurumDegistir(sirket, false);
          } else if (value == 'activate') {
            _sirketDurumDegistir(sirket, true);
          } else if (value == 'delete') {
            showDialog(
              context: context,
              barrierDismissible: true,
              barrierColor: Colors.black.withValues(alpha: 0.35),
              builder: (context) => OnayDialog(
                baslik: tr('common.delete'),
                mesaj: tr(
                  'common.confirm_delete_named',
                ).replaceAll('{name}', sirket.ad),
                onayButonMetni: tr('common.delete'),
                iptalButonMetni: tr('common.cancel'),
                isDestructive: true,
                onOnay: () => _sirketSil(sirket),
              ),
            );
          }
        },
      ),
    );
  }

  List<GridColumn> _buildColumns() {
    return [
      GridColumn(
        columnName: 'checkbox',
        allowSorting: false,
        label: AnimatedBuilder(
          animation: _veriKaynagi,
          builder: (context, child) {
            return Container(
              alignment: Alignment.center,
              child: Checkbox(
                value: _veriKaynagi.selectAllState,
                tristate: true,
                onChanged: (value) {
                  _veriKaynagi.selectAll(value ?? false);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
              ),
            );
          },
        ),
        width: 50,
      ),
      GridColumn(
        columnName: 'id',
        visible: false,
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: Text(tr('common.id')),
        ),
      ),
      GridColumn(
        columnName: 'kod',
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            tr('settings.company.form.code'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ),
        minimumWidth: 120,
        columnWidthMode: ColumnWidthMode.fill,
      ),
      GridColumn(
        columnName: 'ad',
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            tr('settings.company.form.name'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ),
        minimumWidth: 200,
        columnWidthMode: ColumnWidthMode.fill,
      ),
      GridColumn(
        columnName: 'varsayilan',
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            tr('common.default'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ),
        minimumWidth: 120,
        columnWidthMode: ColumnWidthMode.fill,
      ),
      GridColumn(
        columnName: 'durum',
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            tr('common.status'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ),
        minimumWidth: 120,
        columnWidthMode: ColumnWidthMode.fill,
      ),
      GridColumn(
        columnName: 'duzenlenebilir',
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            tr('settings.company.editable'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ),
        minimumWidth: 100,
        columnWidthMode: ColumnWidthMode.fill,
      ),
      GridColumn(
        columnName: 'baslik_sayisi',
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            tr('settings.company.header_count'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ),
        minimumWidth: 100,
        columnWidthMode: ColumnWidthMode.fill,
      ),

      GridColumn(
        columnName: 'actions',
        allowSorting: false,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            tr('common.actions'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ),
        width: 100,
      ),
    ];
  }
}

class _CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _CustomSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF28A745) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            if (value)
              const Positioned(
                left: 5,
                top: 0,
                bottom: 0,
                child: Icon(Icons.check, color: Colors.white, size: 14),
              ),
            if (!value)
              Positioned(
                right: 5,
                top: 0,
                bottom: 0,
                child: Icon(Icons.close, color: Color(0xFF757575), size: 14),
              ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
