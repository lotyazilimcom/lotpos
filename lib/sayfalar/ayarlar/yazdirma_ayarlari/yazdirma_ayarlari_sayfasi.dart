import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/yazdirma_veritabani_servisi.dart';
import 'modeller/yazdirma_sablonu_model.dart';
import 'tasarimci/yazdirma_sablon_tasarimci.dart';

class YazdirmaAyarlariSayfasi extends StatefulWidget {
  const YazdirmaAyarlariSayfasi({super.key});

  @override
  State<YazdirmaAyarlariSayfasi> createState() =>
      _YazdirmaAyarlariSayfasiState();
}

class _YazdirmaAyarlariSayfasiState extends State<YazdirmaAyarlariSayfasi> {
  final YazdirmaVeritabaniServisi _dbServisi = YazdirmaVeritabaniServisi();
  List<YazdirmaSablonuModel> _sablonlar = [];
  bool _yukleniyor = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _yukle();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final list = await _dbServisi.sablonlariGetir();
    setState(() {
      _sablonlar = list;
      _yukleniyor = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _buildGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _yeniSablonOlustur,
        backgroundColor: const Color(0xFFEA4335),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('settings.print.actions.addNew')),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('nav.print_settings'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('settings.print.subtitle'),
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: tr('settings.print.search.placeholder'),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final filtrelenmis = _sablonlar.where((s) {
      return s.name.toLowerCase().contains(_searchQuery) ||
          s.docType.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtrelenmis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.print_disabled_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              tr('settings.print.noTemplates'),
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 0.8,
      ),
      itemCount: filtrelenmis.length,
      itemBuilder: (context, index) => _buildTemplateCard(filtrelenmis[index]),
    );
  }

  Widget _buildTemplateCard(YazdirmaSablonuModel sablon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () => _sablonDuzenle(sablon),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: _TemplateBlueprintPreview(sablon: sablon),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sablon.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () => _sablonIsimlendir(sablon),
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: const Color(0xFF2C3E50).withValues(alpha: 0.5),
                        ),
                      ),
                      if (sablon.isDefault) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tr('settings.print.types.${sablon.docType}')} • ${sablon.paperSize}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        color: Colors.red[400],
                        onPressed: () => _sablonSil(sablon),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () => _sablonKopyala(sablon),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        color: const Color(0xFF2C3E50),
                        onPressed: () => _sablonDuzenle(sablon),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _yeniSablonOlustur() {
    _sablonGoster(null);
  }

  void _sablonDuzenle(YazdirmaSablonuModel sablon) {
    _sablonGoster(sablon);
  }

  void _sablonGoster(YazdirmaSablonuModel? sablon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YazdirmaSablonTasarimci(sablon: sablon),
      ),
    ).then((_) => _yukle());
  }

  Future<void> _sablonSil(YazdirmaSablonuModel sablon) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('settings.print.deleteConfirm.title')),
        content: Text(tr('settings.print.deleteConfirm.message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );

    if (onay == true && sablon.id != null) {
      await _dbServisi.sablonSil(sablon.id!);
      _yukle();
    }
  }

  Future<void> _sablonKopyala(YazdirmaSablonuModel sablon) async {
    final yeniSablon = YazdirmaSablonuModel(
      name: '${sablon.name} (Copy)',
      docType: sablon.docType,
      paperSize: sablon.paperSize,
      customWidth: sablon.customWidth,
      customHeight: sablon.customHeight,
      itemRowSpacing: sablon.itemRowSpacing,
      backgroundImage: sablon.backgroundImage,
      backgroundOpacity: sablon.backgroundOpacity,
      backgroundX: sablon.backgroundX,
      backgroundY: sablon.backgroundY,
      backgroundWidth: sablon.backgroundWidth,
      backgroundHeight: sablon.backgroundHeight,
      layout: List.from(sablon.layout),
      isDefault: false,
      isLandscape: sablon.isLandscape,
    );
    await _dbServisi.sablonEkle(yeniSablon);
    _yukle();
  }

  Future<void> _sablonIsimlendir(YazdirmaSablonuModel sablon) async {
    final controller = TextEditingController(text: sablon.name);
    final yeniIsim = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('settings.print.renameDialog.title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('settings.print.renameDialog.hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
            ),
            child: Text(tr('common.save')),
          ),
        ],
      ),
    );

    if (yeniIsim != null && yeniIsim.isNotEmpty && yeniIsim != sablon.name) {
      final guncelModel = YazdirmaSablonuModel(
        id: sablon.id,
        name: yeniIsim,
        docType: sablon.docType,
        paperSize: sablon.paperSize,
        customWidth: sablon.customWidth,
        customHeight: sablon.customHeight,
        itemRowSpacing: sablon.itemRowSpacing,
        backgroundImage: sablon.backgroundImage,
        backgroundOpacity: sablon.backgroundOpacity,
        backgroundX: sablon.backgroundX,
        backgroundY: sablon.backgroundY,
        backgroundWidth: sablon.backgroundWidth,
        backgroundHeight: sablon.backgroundHeight,
        layout: sablon.layout,
        isDefault: sablon.isDefault,
        isLandscape: sablon.isLandscape,
        viewMatrix: sablon.viewMatrix,
      );
      await _dbServisi.sablonGuncelle(guncelModel);
      _yukle();
    }
  }
}

class _TemplateBlueprintPreview extends StatelessWidget {
  final YazdirmaSablonuModel sablon;

  const _TemplateBlueprintPreview({required this.sablon});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paperSizeMM = _getPaperSizeMM(
          sablon.paperSize,
          sablon.isLandscape,
          sablon.customWidth,
          sablon.customHeight,
        );

        final scaleX = constraints.maxWidth / paperSizeMM.width;
        final scaleY = constraints.maxHeight / paperSizeMM.height;
        final scale = math.min(scaleX, scaleY) * 0.9;

        final previewWidth = paperSizeMM.width * scale;
        final previewHeight = paperSizeMM.height * scale;

        return Center(
          child: Container(
            width: previewWidth,
            height: previewHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                // Arkaplan
                if (sablon.backgroundImage != null)
                  Opacity(
                    opacity: sablon.backgroundOpacity,
                    child: Image.memory(
                      base64Decode(sablon.backgroundImage!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),

                // Blueprint Elemanlar
                ...sablon.layout.map((e) {
                  return Positioned(
                    left: e.x * scale,
                    top: e.y * scale,
                    width: e.width * scale,
                    height: e.height * scale,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFF2C3E50).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Size _getPaperSizeMM(
    String? size,
    bool isLandscape,
    double? customW,
    double? customH,
  ) {
    Size baseSize;
    switch (size) {
      case 'A4':
        baseSize = const Size(210, 297);
        break;
      case 'A5':
        baseSize = const Size(148, 210);
        break;
      case 'Continuous':
        baseSize = const Size(240, 280);
        break;
      case 'Thermal80':
        baseSize = const Size(80, 200);
        break;
      case 'Thermal58':
        baseSize = const Size(58, 150);
        break;
      case 'Custom':
        baseSize = Size(customW ?? 210, customH ?? 297);
        break;
      default:
        baseSize = const Size(210, 297);
    }
    return isLandscape ? Size(baseSize.height, baseSize.width) : baseSize;
  }
}
