import 'dart:async';
import 'package:flutter/material.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import 'modeller/depo_model.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../ortak/genisletilebilir_print_preview_screen.dart';

// --- WAREHOUSE STOCK DETAIL DIALOG (Matching Product Search Style) ---
class WarehouseStockDialog extends StatefulWidget {
  final DepoModel depo;
  final GenelAyarlarModel genelAyarlar;

  const WarehouseStockDialog({
    super.key,
    required this.depo,
    required this.genelAyarlar,
  });

  @override
  State<WarehouseStockDialog> createState() => _WarehouseStockDialogState();
}

class _WarehouseStockDialogState extends State<WarehouseStockDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _stocks = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  // Stats for the info card inside dialog
  double _totalStock = 0;
  int _productCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStocks('');
    _fetchStats(); // Fetch fresh stats for the card
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchStocks(query);
    });
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await DepolarVeritabaniServisi().depoIstatistikleriniGetir(
        widget.depo.id,
      );
      if (mounted) {
        setState(() {
          _totalStock = (stats['toplamUrunMiktari'] as num).toDouble();
          _productCount = (stats['urunSayisi'] as int);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStocks(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await DepolarVeritabaniServisi().depoStoklariniListele(
        widget.depo.id,
        aramaTerimi: query,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _stocks = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isLoading = true);
    try {
      // 1. Calculate Stats
      double totalStock = 0;
      int productCount = _stocks.length;

      for (final stock in _stocks) {
        final qty = (stock['quantity'] as num?)?.toDouble() ?? 0.0;
        totalStock += qty;
      }

      // 2. Prepare Header Info
      final Map<String, dynamic> headerInfo = {
        'icon': widget.depo.ad.isNotEmpty
            ? widget.depo.ad[0].toUpperCase()
            : '?',
        'name': widget.depo.ad,
        'responsible': widget.depo.sorumlu.isNotEmpty
            ? widget.depo.sorumlu
            : null,
        'phone': widget.depo.telefon.isNotEmpty ? widget.depo.telefon : null,
        'address': widget.depo.adres.isNotEmpty ? widget.depo.adres : null,
        'totalStockLabel': tr('warehouses.detail.total_stock'),
        'totalStock': FormatYardimcisi.sayiFormatla(
          totalStock,
          binlik: widget.genelAyarlar.binlikAyiraci,
          ondalik: widget.genelAyarlar.ondalikAyiraci,
          decimalDigits: widget.genelAyarlar.miktarOndalik,
        ),
        'productCount': '($productCount ${tr('common.product')})',
      };

      List<ExpandableRowData> rows = [];

      for (final stock in _stocks) {
        String featuresText = '';
        if (stock['features'] != null) {
          if (stock['features'] is List) {
            featuresText = (stock['features'] as List)
                .map((f) {
                  if (f is Map) return f['name']?.toString() ?? '';
                  return f.toString();
                })
                .join(', ');
          } else {
            featuresText = stock['features'].toString();
          }
        }

        final mainRow = [
          stock['product_name']?.toString() ?? '',
          stock['product_code']?.toString() ?? '',
          stock['barcode']?.toString() ?? '',
          stock['group']?.toString() ?? '',
          FormatYardimcisi.sayiFormatla(
            (stock['quantity'] as num).toDouble(),
            binlik: widget.genelAyarlar.binlikAyiraci,
            ondalik: widget.genelAyarlar.ondalikAyiraci,
            decimalDigits: widget.genelAyarlar.miktarOndalik,
          ),
          stock['unit']?.toString() ?? '',
          featuresText,
        ];

        rows.add(ExpandableRowData(mainRow: mainRow));
      }

      if (!mounted) return;

      final headers = [
        tr('products.table.name'),
        tr('products.table.code'),
        tr('products.table.barcode'),
        tr('products.table.group'),
        tr('products.table.stock'),
        tr('products.table.unit'),
        tr('products.table.features'),
      ];

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GenisletilebilirPrintPreviewScreen(
            title: '${tr('warehouses.detail_title')} - ${widget.depo.ad}',
            headers: headers,
            data: rows,
            headerInfo: headerInfo,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Print error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;
    final Size screenSize = MediaQuery.of(context).size;
    final bool isCompact = screenSize.width < 720;
    final bool isVeryCompact = screenSize.width < 560;
    final double horizontalInset = isVeryCompact ? 10 : (isCompact ? 16 : 32);
    final double verticalInset = isVeryCompact ? 12 : 24;
    final double horizontalPadding = isCompact ? 16 : 28;
    final double maxDialogWidth = isCompact
        ? screenSize.width - (horizontalInset * 2)
        : 720;
    final double maxDialogHeight = isCompact ? screenSize.height * 0.92 : 750;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: maxDialogWidth,
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          isCompact ? 18 : 24,
          horizontalPadding,
          isCompact ? 16 : 22,
        ),
        child: Column(
          children: [
            if (!isVeryCompact)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('warehouses.detail_title'),
                          style: TextStyle(
                            fontSize: isCompact ? 19 : 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.depo.ad} - ${tr('warehouses.stock_list')}',
                          style: TextStyle(
                            fontSize: isCompact ? 13 : 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF606368),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(
                            Icons.print_outlined,
                            size: 22,
                            color: Color(0xFF3C4043),
                          ),
                          onPressed: _handlePrint,
                          tooltip: tr('common.print'),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          tooltip: tr('common.close'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('warehouses.detail_title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.depo.ad,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF606368),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.print_outlined,
                          size: 20,
                          color: Color(0xFF3C4043),
                        ),
                        onPressed: _handlePrint,
                        tooltip: tr('common.print'),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF3C4043),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: tr('common.close'),
                      ),
                    ],
                  ),
                ],
              ),
            SizedBox(height: isCompact ? 14 : 20),
            _buildInfoCard(compact: isCompact, veryCompact: isVeryCompact),
            SizedBox(height: isCompact ? 14 : 20),
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: TextStyle(
                fontSize: isCompact ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                hintText: tr('products.search_placeholder'),
                prefixIcon: Icon(
                  Icons.search,
                  size: isCompact ? 18 : 20,
                  color: const Color(0xFFBDC1C6),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isCompact ? 10 : 12,
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
            SizedBox(height: isCompact ? 14 : 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _stocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: isCompact ? 40 : 48,
                            color: const Color(0xFFE0E0E0),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tr('products.no_products_found'),
                            style: TextStyle(
                              fontSize: isCompact ? 14 : 16,
                              color: const Color(0xFF606368),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _stocks.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) =>
                          _buildStockRow(_stocks[index], compact: isCompact),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required bool compact, required bool veryCompact}) {
    final Widget iconBox = Container(
      width: compact ? 44 : 50,
      height: compact ? 44 : 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          widget.depo.ad.isNotEmpty ? widget.depo.ad[0].toUpperCase() : 'D',
          style: TextStyle(
            fontSize: compact ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF475569),
          ),
        ),
      ),
    );

    final Widget statsBlock = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            tr('warehouses.detail.total_stock'),
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            FormatYardimcisi.sayiFormatla(
              _totalStock,
              binlik: widget.genelAyarlar.binlikAyiraci,
              ondalik: widget.genelAyarlar.ondalikAyiraci,
              decimalDigits: widget.genelAyarlar.miktarOndalik,
            ),
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '($_productCount ${tr('common.product')})',
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.depo.ad,
          style: TextStyle(
            fontSize: compact ? 15 : 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildInlineMeta(
              icon: Icons.person_outline,
              text: widget.depo.sorumlu,
              compact: compact,
            ),
            if (widget.depo.telefon.isNotEmpty)
              _buildInlineMeta(
                icon: Icons.phone_outlined,
                text: widget.depo.telefon,
                compact: compact,
              ),
          ],
        ),
        if (widget.depo.adres.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildInlineMeta(
            icon: Icons.location_on_outlined,
            text: widget.depo.adres,
            compact: compact,
          ),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: veryCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: statsBlock),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(width: 16),
                Expanded(child: details),
                const SizedBox(width: 12),
                statsBlock,
              ],
            ),
    );
  }

  Widget _buildInlineMeta({
    required IconData icon,
    required String text,
    required bool compact,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 13 : 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStockRow(Map<String, dynamic> stock, {required bool compact}) {
    final String productName = stock['product_name']?.toString() ?? '';
    final String productCode = stock['product_code']?.toString() ?? '';
    final String barcode = stock['barcode']?.toString() ?? '';
    final String group = stock['group']?.toString() ?? '';
    final List<dynamic> features = stock['features'] is List
        ? stock['features'] as List<dynamic>
        : const [];
    final double quantity = (stock['quantity'] as num?)?.toDouble() ?? 0;
    final String unit = stock['unit']?.toString() ?? '';

    final quantityText =
        '${FormatYardimcisi.sayiFormatla(quantity, binlik: widget.genelAyarlar.binlikAyiraci, ondalik: widget.genelAyarlar.ondalikAyiraci, decimalDigits: widget.genelAyarlar.miktarOndalik)} $unit';

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 12,
        horizontal: compact ? 4 : 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 44 : 54,
            height: compact ? 44 : 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: const Color(0xFF0277BD),
              size: compact ? 20 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF202124),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quantityText,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E7E34),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      productCode,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF606368),
                      ),
                    ),
                    if (barcode.isNotEmpty) ...[
                      const Icon(
                        Icons.qr_code,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      Text(
                        barcode,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          color: const Color(0xFF606368),
                        ),
                      ),
                    ],
                  ],
                ),
                if (group.isNotEmpty || features.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (group.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              group,
                              style: TextStyle(
                                fontSize: compact ? 11 : 12,
                                color: const Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ...features
                            .map(
                              (feature) => _buildFeatureChip(feature, compact),
                            )
                            .where((chip) => chip != null)
                            .cast<Widget>(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFeatureChip(dynamic feature, bool compact) {
    String text = '';
    Color? featureColor;

    if (feature is Map) {
      text = feature['name']?.toString() ?? '';
      if (feature['color'] != null) {
        try {
          featureColor = Color(int.parse(feature['color'].toString()));
        } catch (_) {}
      }
    } else {
      text = feature?.toString() ?? '';
    }

    if (text.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: featureColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: featureColor != null
              ? featureColor.withValues(alpha: 0.2)
              : Colors.grey.shade300,
        ),
        boxShadow: featureColor != null
            ? [
                BoxShadow(
                  color: featureColor.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          color: featureColor != null
              ? (ThemeData.estimateBrightnessForColor(featureColor) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black87)
              : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
