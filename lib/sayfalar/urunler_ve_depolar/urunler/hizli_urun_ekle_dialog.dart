import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../yardimcilar/responsive_yardimcisi.dart';
import '../../../servisler/yapay_zeka_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import "../../../servisler/urunler_veritabani_servisi.dart";
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../depolar/modeller/depo_model.dart';
import 'modeller/urun_model.dart';
import 'modeller/cihaz_model.dart';
import '../../../bilesenler/tek_tarih_secici_dialog.dart';

class HizliUrunEkleDialog extends StatefulWidget {
  const HizliUrunEkleDialog({super.key});

  @override
  State<HizliUrunEkleDialog> createState() => _HizliUrunEkleDialogState();
}

class _HizliUrunEkleDialogState extends State<HizliUrunEkleDialog> {
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isAiScanning = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  int? _selectedWarehouseId;
  List<DepoModel> _warehouses = [];
  final List<String> _deviceConditions = [
    'common.condition.new',
    'common.condition.used',
    'common.condition.refurbished',
    'common.condition.broken',
  ];

  final ScrollController _horizontalScroll = ScrollController();

  static const Color primaryColor = Color(0xFF2C3E50);

  int _selectedIndex = 0;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    final warehouses = await DepolarVeritabaniServisi().depolariGetir();

    // Değerleri kaydet (shared preferences'dan varsayılan depoyu almayı da deneyebiliriz)
    final prefs = await SharedPreferences.getInstance();
    final defaultWhId = prefs.getInt('varsayilan_depo_id');

    if (mounted) {
      setState(() {
        _genelAyarlar = settings;
        _warehouses = warehouses;
        _selectedWarehouseId =
            defaultWhId ?? (warehouses.isNotEmpty ? warehouses.first.id : null);

        // Settings yüklendikten sonra ilk satırı ekle (varsayılan depo ile)
        if (_items.isEmpty) {
          _addRow();
        }
      });
    }
  }

  void _addRow() {
    setState(() {
      final newItem = {
        'kod': TextEditingController(),
        'ad': TextEditingController(),
        'barkod': TextEditingController(),
        'alisFiyati': TextEditingController(),
        'satisFiyati1': TextEditingController(),
        'satisFiyati2': TextEditingController(),
        'satisFiyati3': TextEditingController(),
        'kdvOrani': TextEditingController(text: '20'),
        'stok': TextEditingController(text: '1'),
        'kritikStok': TextEditingController(text: '0'),
        'birim': tr('common.default_unit'),
        'grubu': tr('common.general'),
        'depoId': _selectedWarehouseId,
        'renk': TextEditingController(),
        'kapasite': TextEditingController(),
        'durum': 'common.condition.new',
        'garantiBitis': null as DateTime?,
        'imeiList': <String>[],
        'ozellikler': TextEditingController(),
        'resimler': <String>[], // Up to 5 images
        'focusNodes': {
          'kod': FocusNode(),
          'ad': FocusNode(),
          'barkod': FocusNode(),
          'alisFiyati': FocusNode(),
          'satisFiyati1': FocusNode(),
          'stok': FocusNode(),
          'kdvOrani': FocusNode(),
          'kritikStok': FocusNode(),
        },
      };
      _attachFormattersToRow(newItem);
      _items.add(newItem);
      _selectedIndex = _items.length - 1;
    });
  }

  void _attachFormattersToRow(Map<String, dynamic> item) {
    final nodes = item['focusNodes'] as Map<String, FocusNode>;
    _attachPriceFormatter(nodes['alisFiyati']!, item['alisFiyati']);
    _attachPriceFormatter(nodes['satisFiyati1']!, item['satisFiyati1']);
    _attachGenericFormatter(
      nodes['stok']!,
      item['stok'],
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
    _attachGenericFormatter(
      nodes['kdvOrani']!,
      item['kdvOrani'],
      decimalDigits: 2,
      isOran: true,
    );
    _attachGenericFormatter(
      nodes['kritikStok']!,
      item['kritikStok'],
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
  }

  void _attachPriceFormatter(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      if (!node.hasFocus) {
        final val = FormatYardimcisi.parseDouble(
          controller.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
        if (val == 0 && controller.text.isEmpty) return;
        controller.text = FormatYardimcisi.sayiFormatlaOndalikli(
          val,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
      }
    });
  }

  void _attachGenericFormatter(
    FocusNode node,
    TextEditingController controller, {
    int decimalDigits = 2,
    bool isOran = false,
  }) {
    node.addListener(() {
      if (!node.hasFocus) {
        final val = FormatYardimcisi.parseDouble(
          controller.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
        if (val == 0 && controller.text.isEmpty) return;

        if (isOran) {
          controller.text = FormatYardimcisi.sayiFormatlaOran(
            val,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: decimalDigits,
          );
        } else {
          controller.text = FormatYardimcisi.sayiFormatla(
            val,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: decimalDigits,
          );
        }
      }
    });
  }

  void _removeRow(int index) {
    if (_items.length <= 1) {
      // Clear instead of removing last row
      final item = _items[index];
      (item['kod'] as TextEditingController).clear();
      (item['ad'] as TextEditingController).clear();
      (item['barkod'] as TextEditingController).clear();
      (item['alisFiyati'] as TextEditingController).clear();
      (item['satisFiyati1'] as TextEditingController).clear();
      (item['satisFiyati2'] as TextEditingController).clear();
      (item['satisFiyati3'] as TextEditingController).clear();
      (item['kdvOrani'] as TextEditingController).text = '20';
      (item['stok'] as TextEditingController).text = '1';
      (item['kritikStok'] as TextEditingController).text = '0';
      (item['renk'] as TextEditingController).clear();
      (item['kapasite'] as TextEditingController).clear();
      item['durum'] = 'Sıfır';
      item['garantiBitis'] = null;
      (item['imeiList'] as List<String>).clear();
      (item['ozellikler'] as TextEditingController).clear();
      return;
    }
    setState(() {
      final item = _items[index];
      (item['kod'] as TextEditingController).dispose();
      (item['ad'] as TextEditingController).dispose();
      (item['barkod'] as TextEditingController).dispose();
      (item['alisFiyati'] as TextEditingController).dispose();
      (item['satisFiyati1'] as TextEditingController).dispose();
      (item['satisFiyati2'] as TextEditingController).dispose();
      (item['satisFiyati3'] as TextEditingController).dispose();
      (item['kdvOrani'] as TextEditingController).dispose();
      (item['stok'] as TextEditingController).dispose();
      (item['kritikStok'] as TextEditingController).dispose();
      (item['renk'] as TextEditingController).dispose();
      (item['kapasite'] as TextEditingController).dispose();
      (item['ozellikler'] as TextEditingController).dispose();
      (item['focusNodes'] as Map<String, FocusNode>).forEach(
        (k, v) => v.dispose(),
      );
      _items.removeAt(index);
      if (_selectedIndex >= _items.length) {
        _selectedIndex = _items.length - 1;
      }
      if (_selectedIndex < 0) _selectedIndex = 0;
    });
  }

  Future<void> _handleAiScan() async {
    final XTypeGroup typeGroup = XTypeGroup(
      label: tr('common.images'),
      extensions: <String>['jpg', 'jpeg', 'png'],
      uniformTypeIdentifiers: ['public.image'],
    );
    final List<XFile> pickedFiles = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );

    if (pickedFiles.isEmpty) return;

    setState(() => _isAiScanning = true);

    try {
      final List<Uint8List> allImageBytes = [];
      final List<String> allImageBase64 = [];

      for (final file in pickedFiles) {
        final bytes = await file.readAsBytes();
        allImageBytes.add(bytes);
        allImageBase64.add(base64Encode(bytes));
      }

      final result = await YapayZekaServisi().analizEtHizliUrun(allImageBytes);

      if (result['urunler'] != null) {
        final urunlerList = result['urunler'] as List;
        setState(() {
          // Eğer tek bir satır varsa ve boşsa, AI sonuçlarını eklemeden önce temizle
          if (_items.length == 1) {
            final firstRowAd = (_items[0]['ad'] as TextEditingController).text;
            final firstRowKod =
                (_items[0]['kod'] as TextEditingController).text;
            if (firstRowAd.trim().isEmpty && firstRowKod.trim().isEmpty) {
              _items.clear();
            }
          }

          for (final u in urunlerList) {
            final ad = u['ad']?.toString() ?? '';
            if (ad.isEmpty) continue;

            final aiResimler = u['resimler'] as List?;
            final matchedImages = <String>[];

            if (aiResimler != null) {
              for (var imgObj in aiResimler) {
                if (imgObj is Map<String, dynamic>) {
                  final idx = imgObj['index'];
                  final tip = imgObj['tip'];

                  // Sadece 'urun' tipindeki resimleri kaydet
                  if (tip == 'urun' &&
                      idx is int &&
                      idx >= 0 &&
                      idx < allImageBase64.length) {
                    matchedImages.add(allImageBase64[idx]);
                  }
                }
              }
            }

            _addRowFromAi(u, resimlerBase64: matchedImages);
          }
          _selectedIndex = 0;
        });
      }

      if (mounted) {
        MesajYardimcisi.basariGoster(context, tr('expenses.ai.scan_success'));
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, 'Yapay zeka analizi hatası: $e');
      }
    } finally {
      if (mounted) setState(() => _isAiScanning = false);
    }
  }

  void _addRowFromAi(
    Map<String, dynamic> data, {
    List<String> resimlerBase64 = const [],
  }) {
    final kodCtrl = TextEditingController(text: data['kod']?.toString() ?? '');
    final adCtrl = TextEditingController(text: data['ad']?.toString() ?? '');
    final barkodCtrl = TextEditingController(
      text: data['barkod']?.toString() ?? '',
    );

    final alis = FormatYardimcisi.sayiFormatlaOndalikli(
      (data['alisFiyati'] as num?)?.toDouble() ?? 0.0,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );
    final alisCtrl = TextEditingController(text: alis);

    final satis1 = FormatYardimcisi.sayiFormatlaOndalikli(
      (data['satisFiyati1'] as num?)?.toDouble() ?? 0.0,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );
    final satis1Ctrl = TextEditingController(text: satis1);

    final kdvVal = (data['kdvOrani'] as num?)?.toDouble() ?? 20.0;
    final kdvCtrl = TextEditingController(
      text: FormatYardimcisi.sayiFormatlaOran(
        kdvVal,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      ),
    );

    final stokVal = (data['stok'] as num?)?.toDouble() ?? 1.0;
    final stokCtrl = TextEditingController(
      text: FormatYardimcisi.sayiFormatla(
        stokVal,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.miktarOndalik,
      ),
    );
    final ozelliklerCtrl = TextEditingController(
      text: data['ozellikler']?.toString() ?? '',
    );
    final renkCtrl = TextEditingController(
      text: data['renk']?.toString() ?? '',
    );
    final kapasiteCtrl = TextEditingController(
      text: data['kapasite']?.toString() ?? '',
    );

    DateTime? garantiBitis;
    if (data['garantiBitis'] != null) {
      try {
        garantiBitis = DateTime.parse(data['garantiBitis'].toString());
      } catch (_) {}
    }

    final imeiList = <String>[];
    if (data['imeiList'] != null && data['imeiList'] is List) {
      for (var imei in data['imeiList']) {
        imeiList.add(imei.toString());
      }
    }

    _items.add({
      'kod': kodCtrl,
      'ad': adCtrl,
      'barkod': barkodCtrl,
      'alisFiyati': alisCtrl,
      'satisFiyati1': satis1Ctrl,
      'satisFiyati2': TextEditingController(),
      'satisFiyati3': TextEditingController(),
      'kdvOrani': kdvCtrl,
      'stok': stokCtrl,
      'kritikStok': TextEditingController(text: '0'),
      'birim': data['birim']?.toString() ?? 'Adet',
      'grubu': data['grubu']?.toString() ?? tr('common.general'),
      'depoId': _selectedWarehouseId,
      'renk': renkCtrl,
      'kapasite': kapasiteCtrl,
      'durum': data['durum']?.toString() ?? 'Sıfır',
      'garantiBitis': garantiBitis,
      'imeiList': imeiList,
      'ozellikler': ozelliklerCtrl,
      'resimler': resimlerBase64,
      'focusNodes': {
        'kod': FocusNode(),
        'ad': FocusNode(),
        'barkod': FocusNode(),
        'alisFiyati': FocusNode(),
        'satisFiyati1': FocusNode(),
        'stok': FocusNode(),
      },
    });
  }

  Future<void> _showImeiPopup(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: item['imeiList'].join('\n'));

    await showDialog<List<String>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 680),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('products.quick_add.bulk_add_title'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('products.quick_add.bulk_add_hint'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF606368),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('common.esc'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9AA0A6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(
                            Icons.close,
                            size: 22,
                            color: Color(0xFF3C4043),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Input Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('products.quick_add.bulk_add_list_title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF202124),
                        ),
                        decoration: InputDecoration(
                          hintText: tr(
                            'products.quick_add.bulk_add_hint_example',
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          fillColor: const Color(0xFFF8F9FA),
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2C3E50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      tr('common.cancel'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final lines = controller.text
                          .split(RegExp(r'[\n,;]'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      setState(() {
                        item['imeiList'] = lines;
                        item['stok'].text = lines.length.toString();
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA4335),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      tr('common.ok'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isMobile =>
      ResponsiveYardimcisi.tabletMi(context) ||
      MediaQuery.sizeOf(context).width < 900;

  @override
  Widget build(BuildContext context) {
    if (_isMobile) {
      return _buildMobileLayout();
    }
    return _buildDesktopLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tr('products.quick_add.title'),
          style: const TextStyle(
            color: Color(0xFF202124),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF5F6368)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: Text(
              tr('common.save'),
              style: const TextStyle(
                color: Color(0xFFEA4335),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMobileToolbar(),
          Expanded(child: _buildMobileList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildMobileToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAiActionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Kamerayı Kullan',
                  onPressed: _handleAiScan,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAiActionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeriden Seç',
                  onPressed: _handleAiScan,
                  color: const Color(0xFFF39C12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ürün resmini çekerek veya seçerek yapay zeka ile otomatik ekleyebilirsiniz.',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
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

  Widget _buildAiActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: _isAiScanning ? null : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            if (_isAiScanning)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              )
            else
              Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz ürün eklenmedi',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildMobileItemCard(index),
    );
  }

  Widget _buildMobileItemCard(int index) {
    final item = _items[index];
    final images = item['resimler'] as List<String>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _showMobileItemEditor(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty)
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(images.first)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['ad'] as TextEditingController).text.isEmpty
                              ? 'İsimsiz Ürün'
                              : (item['ad'] as TextEditingController).text,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Barkod: ${(item['barkod'] as TextEditingController).text.isEmpty ? '-' : (item['barkod'] as TextEditingController).text}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        if (_genelAyarlar.cihazListesiModuluAktif) ...[
                          const SizedBox(height: 4),
                          Text(
                            'IMEI/Seri: ${(item['imeiList'] as List).length}',
                            style: TextStyle(
                              color: primaryColor.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeRow(index),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildMobileMiniField(
                      label: tr('products.table.sales_price_1'),
                      controller: item['satisFiyati1'],
                      isNumeric: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMobileMiniField(
                      label: tr('products.table.stock'),
                      controller: item['stok'],
                      isNumeric: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showMobileItemEditor(index),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Detayları Düzenle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMiniField({
    required String label,
    required TextEditingController controller,
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              keyboardType: isNumeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMobileItemEditor(int index) {
    setState(() => _selectedIndex = index);
    if (ResponsiveYardimcisi.tabletMi(context)) {
      _showTabletItemEditorDialog(index);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Ürün Detayları',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _mobileEditorField('Ürün Adı', _items[index]['ad']),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _mobileEditorField(
                            'Barkod',
                            _items[index]['barkod'],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _mobileEditorField(
                            'Ürün Kodu',
                            _items[index]['kod'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _mobileEditorField(
                            'Alış Fiyatı',
                            _items[index]['alisFiyati'],
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _mobileEditorField(
                            'Satış Fiyatı',
                            _items[index]['satisFiyati1'],
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _mobileEditorField(
                            'KDV',
                            _items[index]['kdvOrani'],
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _mobileEditorField(
                            'Stok',
                            _items[index]['stok'],
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Resimler',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMobileResimler(index),
                    if (_genelAyarlar.cihazListesiModuluAktif) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'IMEI / Seri Numaraları',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobileImeiSection(index),
                    ],
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Bitti',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTabletItemEditorDialog(int index) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final mediaSize = MediaQuery.sizeOf(dialogContext);
        final viewInsets = MediaQuery.viewInsetsOf(dialogContext);

        final maxWidth = math.min(mediaSize.width - 48, 980.0);
        final maxHeight = math.min(mediaSize.height - 48, 900.0);

        return AnimatedPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + viewInsets.bottom),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Ürün Detayları',
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: tr('common.close'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _mobileEditorField(
                                  'Ürün Adı',
                                  _items[index]['ad'],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _mobileEditorField(
                                        'Barkod',
                                        _items[index]['barkod'],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _mobileEditorField(
                                        'Ürün Kodu',
                                        _items[index]['kod'],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _mobileEditorField(
                                        'Alış Fiyatı',
                                        _items[index]['alisFiyati'],
                                        isNumeric: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _mobileEditorField(
                                        'Satış Fiyatı',
                                        _items[index]['satisFiyati1'],
                                        isNumeric: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _mobileEditorField(
                                        'KDV',
                                        _items[index]['kdvOrani'],
                                        isNumeric: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _mobileEditorField(
                                        'Stok',
                                        _items[index]['stok'],
                                        isNumeric: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Resimler',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildMobileResimler(index),
                                if (_genelAyarlar.cihazListesiModuluAktif) ...[
                                  const SizedBox(height: 24),
                                  const Text(
                                    'IMEI / Seri Numaraları',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMobileImeiSection(index),
                                ],
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Bitti',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileEditorField(
    String label,
    TextEditingController controller, {
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImagesForMobileRow(int index) async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: tr('common.images'),
        extensions: <String>['jpg', 'png', 'jpeg'],
        uniformTypeIdentifiers: ['public.image'],
      );
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      if (files.isNotEmpty) {
        final List<String> currentImages = List<String>.from(
          _items[index]['resimler'],
        );
        for (final file in files) {
          if (currentImages.length >= 5) break;
          final bytes = await file.readAsBytes();
          currentImages.add(base64Encode(bytes));
        }
        setState(() => _items[index]['resimler'] = currentImages);
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, tr('common.error_occurred'));
      }
    }
  }

  Widget _buildMobileResimler(int index) {
    final resimler = _items[index]['resimler'] as List<String>;
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: resimler.length < 5 ? resimler.length + 1 : resimler.length,
        itemBuilder: (context, i) {
          if (i == resimler.length && resimler.length < 5) {
            return InkWell(
              onTap: () => _pickImagesForMobileRow(index),
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('common.add'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: MemoryImage(base64Decode(resimler[i])),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      final list = List<String>.from(_items[index]['resimler']);
                      list.removeAt(i);
                      _items[index]['resimler'] = list;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileImeiSection(int index) {
    final imeiList = _items[index]['imeiList'] as List<String>;
    return Column(
      children: [
        ...imeiList.map(
          (imei) => ListTile(
            title: Text(imei),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() {
                  imeiList.remove(imei);
                  _items[index]['stok'].text = imeiList.length.toString();
                });
              },
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => _showImeiPopup(index),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Toplu Ekle'),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    const double tableWidth = 1530.0 + 16.0; // Column widths + padding
    const double outerPadding = 12.0;
    const double totalTargetWidth = tableWidth + (outerPadding * 2);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20), // Consistent 20px gap from screen
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: totalTargetWidth,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.pop(context),
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              padding: const EdgeInsets.all(outerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const Divider(height: 16), // Reduced from 24
                  _buildToolbar(),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: _genelAyarlar.cihazListesiModuluAktif ? 6 : 10,
                    child: _buildTable(),
                  ),
                  if (_genelAyarlar.cihazListesiModuluAktif) ...[
                    const SizedBox(height: 12),
                    Expanded(flex: 4, child: _buildDetailPanel()),
                  ],
                  const Divider(height: 16), // Reduced from 24
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: primaryColor, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('products.quick_add.title'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  tr('products.quick_add.subtitle'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isAiScanning ? null : _handleAiScan,
          icon: _isAiScanning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(tr('products.quick_add.ai_analyze')),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('products.quick_add.add_row')),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: primaryColor),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const Spacer(),
        Text(
          tr(
            'products.quick_add.total_items',
            args: {'count': _items.length.toString()},
          ),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double minTableWidth = 1350.0;
          final double currentWidth = constraints.maxWidth;
          final bool useScroll = currentWidth < minTableWidth;

          Widget table = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _buildTableRow(index),
                ),
              ),
            ],
          );

          if (useScroll) {
            return Scrollbar(
              controller: _horizontalScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minTableWidth, child: table),
              ),
            );
          }

          return SizedBox(width: currentWidth, child: table);
        },
      ),
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: Colors.black54,
    );
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 40, child: Text('#', style: headerStyle)),
          Expanded(
            flex: 4,
            child: _headerCell('${tr('products.table.name')} *'),
          ),
          Expanded(flex: 2, child: _headerCell(tr('common.barcode'))),
          Expanded(flex: 2, child: _headerCell(tr('products.table.code'))),
          _headerCell(tr('common.warehouse'), width: 140),
          _headerCell(tr('common.unit'), width: 90),
          _headerCell(tr('products.table.purchase_price'), width: 110),
          _headerCell(tr('products.table.sales_price_1'), width: 110),
          _headerCell(tr('products.table.vat'), width: 70),
          _headerCell(tr('products.table.stock'), width: 70),
          _headerCell(tr('products.form.group.label'), width: 140),
          _headerCell(tr('common.images'), width: 110),
          const SizedBox(width: 50, child: Text('', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {double? width}) {
    final cell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.black54,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: cell);
    }
    return cell;
  }

  Widget _buildTableRow(int index) {
    final item = _items[index];
    final isSelected = _selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.08)
                : (isHovered ? Colors.grey.shade50 : Colors.white),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100),
              left: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 37, // Adjusted for selection border
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: _tableCell(item['ad'], 'Ürün adı yazın'),
              ),
              Expanded(flex: 2, child: _tableCell(item['barkod'], 'Barkod')),
              Expanded(flex: 2, child: _tableCell(item['kod'], 'Kod')),
              _warehouseDropdownCell(index, 140),
              _dropdownCell(index, 'birim', 90, [
                'Adet',
                'Kg',
                'Lt',
                'Mt',
                'Koli',
              ]),
              _tableCell(
                item['alisFiyati'],
                '0.00',
                width: 110,
                isNumeric: true,
                focusNode: item['focusNodes']['alisFiyati'],
              ),
              _tableCell(
                item['satisFiyati1'],
                '0.00',
                width: 110,
                isNumeric: true,
                focusNode: item['focusNodes']['satisFiyati1'],
              ),
              _tableCell(
                item['kdvOrani'],
                '20',
                width: 70,
                isNumeric: true,
                focusNode: item['focusNodes']['kdvOrani'],
              ),
              _tableCell(
                item['stok'],
                '1',
                width: 70,
                isNumeric: true,
                focusNode: item['focusNodes']['stok'],
              ),
              _dropdownCell(index, 'grubu', 140, [
                tr('common.general'),
                'Elektronik',
                'Giyim',
                'Gıda',
              ]),
              _imageCell(index, 110),
              SizedBox(
                width: 50,
                child: IconButton(
                  onPressed: () => _removeRow(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _warehouseDropdownCell(int index, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _items[index]['depoId'],
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              elevation: 8,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              onChanged: (val) {
                if (val != null) setState(() => _items[index]['depoId'] = val);
              },
              items: _warehouses
                  .map(
                    (w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(w.ad, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateCell(int index, double width) {
    final date = _items[index]['garantiBitis'] as DateTime?;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () async {
            final picked = await showDialog<DateTime>(
              context: context,
              builder: (context) =>
                  TekTarihSeciciDialog(initialDate: date ?? DateTime.now()),
            );
            if (picked != null) {
              setState(() => _items[index]['garantiBitis'] = picked);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date == null
                        ? tr('common.validity_date')
                        : DateFormat('dd.MM.yy').format(date),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableCell(
    TextEditingController controller,
    String hint, {
    double? width,
    bool isNumeric = false,
    FocusNode? focusNode,
  }) {
    final cell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focusNode?.hasFocus == true
                ? primaryColor.withValues(alpha: 0.5)
                : Colors.grey.shade200,
            width: focusNode?.hasFocus == true ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                  ),
                ]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            border: InputBorder.none,
            fillColor: Colors.transparent,
            filled: true,
          ),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: cell);
    }
    return cell;
  }

  Widget _dropdownCell(
    int index,
    String key,
    double width,
    List<String> options,
  ) {
    String? currentValue = _items[index][key];

    // Ensure the current value is in the options list to avoid crashes
    final List<String> effectiveOptions = List.from(options);
    if (currentValue != null && !effectiveOptions.contains(currentValue)) {
      effectiveOptions.add(currentValue);
    }

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              elevation: 8,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              onChanged: (val) {
                if (val != null) setState(() => _items[index][key] = val);
              },
              items: effectiveOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(tr(option), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (_items.isEmpty || _selectedIndex >= _items.length) {
      return const SizedBox();
    }

    final item = _items[_selectedIndex];
    final imeiList = item['imeiList'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: IMEI / Serial List
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.vibration_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr(
                            'products.quick_add.bulk_add_list_title',
                            args: {'count': imeiList.length.toString()},
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _showImeiPopup(_selectedIndex),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(tr('products.quick_add.bulk_add')),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: imeiList.isEmpty
                        ? Center(
                            child: Text(
                              tr('products.quick_add.no_device_added'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: imeiList.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '${i + 1}.',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      imeiList[i],
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(() {
                                      imeiList.removeAt(i);
                                      item['stok'].text = imeiList.length
                                          .toString();
                                    }),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 32),
          // Middle: Vertical Photo Gallery
          if ((item['resimler'] as List).isNotEmpty) ...[
            SizedBox(
              width: 55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('common.images'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: (item['resimler'] as List).length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final base64 = (item['resimler'] as List)[i];
                        return InkWell(
                          onTap: () => _showImagePreview(item['resimler']),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                              image: DecorationImage(
                                image: MemoryImage(base64Decode(base64)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 32),
          ],
          // Right Side: Technical Specs
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.settings_suggest_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('products.quick_add.technical_specs'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _detailItem(
                        tr('products.table.status'),
                        _dropdownCell(
                          _selectedIndex,
                          'durum',
                          140,
                          _deviceConditions,
                        ),
                      ),
                      _detailItem(
                        tr('products.quick_add.alert_quantity'),
                        _tableCell(
                          item['kritikStok'],
                          '0',
                          width: 100,
                          isNumeric: true,
                          focusNode: item['focusNodes']['kritikStok'],
                        ),
                      ),
                      _detailItem(
                        tr('products.form.attribute.name'),
                        _tableCell(
                          item['renk'],
                          tr('products.form.attribute.select_color'),
                          width: 140,
                        ),
                      ),
                      _detailItem(
                        tr('common.description'),
                        _tableCell(
                          item['kapasite'],
                          tr('common.general'),
                          width: 140,
                        ),
                      ),
                      _detailItem(
                        tr('common.validity_date'),
                        _dateCell(_selectedIndex, 140),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('products.quick_add.features_notes'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: item['ozellikler'],
                      maxLines: null,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: tr('products.quick_add.features_hint'),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageCell(int index, double width) {
    final resimler = _items[index]['resimler'] as List<String>;
    final hasImages = resimler.isNotEmpty;

    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  if (hasImages) {
                    _showImagePreview(resimler);
                  } else {
                    MesajYardimcisi.bilgiGoster(
                      context,
                      tr('products.quick_add.no_image_ai_hint'),
                    );
                  }
                },
                tooltip: tr('products.quick_add.image_preview_tooltip'),
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: hasImages
                        ? primaryColor.withValues(alpha: 0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasImages
                        ? Icons.collections_rounded
                        : Icons.no_photography_outlined,
                    size: 18,
                    color: hasImages ? primaryColor : Colors.grey,
                  ),
                ),
              ),
              if (hasImages) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${resimler.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePreview(List<String> base64Images) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: base64Images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.memory(
                      base64Decode(base64Images[index]),
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            if (base64Images.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    tr('products.quick_add.image_swipe_hint'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    // 1. Validation
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item['kod'].text.trim().isEmpty || item['ad'].text.trim().isEmpty) {
        setState(() => _selectedIndex = i);
        MesajYardimcisi.uyariGoster(
          context,
          tr(
            'products.quick_add.error.empty_fields',
            args: {'index': (i + 1).toString()},
          ),
        );
        return;
      }

      final stokDegeri = FormatYardimcisi.parseDouble(
        item['stok'].text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      final depoId = item['depoId'] ?? _selectedWarehouseId;
      if (stokDegeri > 0 && (depoId == null || _warehouses.isEmpty)) {
        setState(() => _selectedIndex = i);
        MesajYardimcisi.hataGoster(
          context,
          tr('shipment.error.warehouse_required'),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final service = UrunlerVeritabaniServisi();
      final prefs = await SharedPreferences.getInstance();
      final currentUser =
          prefs.getString('current_username') ?? tr('common.system');

      // 2. Duplicate Check for all codes
      for (int i = 0; i < _items.length; i++) {
        final code = _items[i]['kod'].text.trim();
        final isDuplicate = await service.urunKoduVarMi(code);
        if (isDuplicate) {
          setState(() {
            _isLoading = false;
            _selectedIndex = i;
          });
          if (!mounted) return;
          MesajYardimcisi.hataGoster(
            context,
            tr(
              'products.quick_add.error.duplicate_code',
              args: {'index': (i + 1).toString(), 'code': code},
            ),
          );
          return;
        }
      }

      // 4. Update Settings with new groups/units if any
      final existingGroups = _genelAyarlar.urunGruplari
          .map((e) => e['name'].toString())
          .toSet();
      final existingUnits = _genelAyarlar.urunBirimleri
          .map((e) => e['name'].toString())
          .toSet();
      bool settingsChanged = false;
      List<Map<String, dynamic>> updatedGroups = List.from(
        _genelAyarlar.urunGruplari,
      );
      List<Map<String, dynamic>> updatedUnits = List.from(
        _genelAyarlar.urunBirimleri,
      );

      for (final item in _items) {
        final group = (item['grubu'] as String?)?.trim() ?? '';
        if (group.isNotEmpty && !existingGroups.contains(group)) {
          updatedGroups.add({'name': group});
          existingGroups.add(group);
          settingsChanged = true;
        }

        final unit = (item['birim'] as String?)?.trim() ?? '';
        if (unit.isNotEmpty && !existingUnits.contains(unit)) {
          updatedUnits.add({'name': unit, 'isDefault': false});
          existingUnits.add(unit);
          settingsChanged = true;
        }
      }

      if (settingsChanged) {
        _genelAyarlar.urunGruplari = updatedGroups;
        _genelAyarlar.urunBirimleri = updatedUnits;
        await AyarlarVeritabaniServisi().genelAyarlariKaydet(_genelAyarlar);
      }

      // 5. Save Each Item
      for (final item in _items) {
        final imeiList = item['imeiList'] as List<String>;
        final List<CihazModel> cihazlar = [];

        for (final imei in imeiList) {
          cihazlar.add(
            CihazModel(
              id: 0,
              productId: 0, // Will be set by urunEkle
              identityType: tr('common.identity.imei'),
              identityValue: imei,
              condition: item['durum'] ?? 'common.condition.new',
              color: item['renk'].text.trim(),
              capacity: item['kapasite'].text.trim(),
              warrantyEndDate: item['garantiBitis'],
              hasBox: false,
              hasInvoice: false,
              hasOriginalCharger: false,
            ),
          );
        }

        // Prepare ozellikler as JSON list (standard for this app)
        final specsText = item['ozellikler'].text.trim();
        final ozelliklerJson = jsonEncode([
          if (specsText.isNotEmpty)
            {
              'name': specsText,
              'color': 0xFF9E9E9E, // Default Grey
            },
        ]);

        final urun = UrunModel(
          id: 0,
          kod: item['kod'].text.trim(),
          ad: item['ad'].text.trim(),
          birim:
              item['birim'] ??
              tr(
                'common.default_unit',
              ), // Updated to use a key if exists or Adet
          alisFiyati: FormatYardimcisi.parseDouble(
            item['alisFiyati'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          satisFiyati1: FormatYardimcisi.parseDouble(
            item['satisFiyati1'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          satisFiyati2: FormatYardimcisi.parseDouble(
            item['satisFiyati2'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          satisFiyati3: FormatYardimcisi.parseDouble(
            item['satisFiyati3'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          kdvOrani: FormatYardimcisi.parseDouble(
            item['kdvOrani'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          stok: FormatYardimcisi.parseDouble(
            item['stok'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          erkenUyariMiktari: FormatYardimcisi.parseDouble(
            item['kritikStok'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          grubu: item['grubu'] ?? tr('common.general'),
          ozellikler: ozelliklerJson,
          barkod: item['barkod'].text.trim(),
          kullanici: currentUser,
          resimler: item['resimler'] as List<String>,
          aktifMi: true,
          cihazlar: cihazlar,
        );

        await service.urunEkle(
          urun,
          initialStockWarehouseId: item['depoId'] ?? _selectedWarehouseId,
          initialStockUnitCost: FormatYardimcisi.parseDouble(
            item['alisFiyati'].text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          createdBy: currentUser,
        );
      }

      if (!mounted) return;
      MesajYardimcisi.basariGoster(
        context,
        tr(
          'products.quick_add.save_success',
          args: {'count': _items.length.toString()},
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(
        context,
        tr('products.quick_add.save_error', args: {'error': e.toString()}),
      );
    }
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              foregroundColor: const Color(0xFF2C3E50),
            ),
            child: Text(tr('common.cancel')),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    tr('products.quick_add.validate_and_save'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
