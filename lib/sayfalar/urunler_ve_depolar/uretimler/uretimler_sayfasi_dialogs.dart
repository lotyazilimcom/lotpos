import 'dart:async';
import 'package:flutter/material.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import 'modeller/uretim_model.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../ortak/genisletilebilir_print_preview_screen.dart';

// --- PRODUCTION RECIPE DIALOG (Same as WarehouseStockDialog) ---
class ProductionRecipeDialog extends StatefulWidget {
  final UretimModel uretim;
  final GenelAyarlarModel genelAyarlar;

  const ProductionRecipeDialog({
    super.key,
    required this.uretim,
    required this.genelAyarlar,
  });

  @override
  State<ProductionRecipeDialog> createState() => _ProductionRecipeDialogState();
}

class _ProductionRecipeDialogState extends State<ProductionRecipeDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _stocks = [];
  List<Map<String, dynamic>> _filteredStocks = [];
  bool _isLoading = false;
  Timer? _debounce;
  int _currentPage = 1;
  final int _rowsPerPage = 10;
  static const Color _primaryColor = Color(0xFF2C3E50);

  // Stats for the info card inside dialog
  int _productCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStocks();
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
      _filterStocks(query);
    });
  }

  void _filterStocks(String query) {
    if (!mounted) return;
    setState(() {
      _currentPage = 1; // Reset to first page on search
      if (query.isEmpty) {
        _filteredStocks = List.from(_stocks);
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredStocks = _stocks.where((stock) {
          final name = (stock['product_name'] as String?)?.toLowerCase() ?? '';
          final code = (stock['product_code'] as String?)?.toLowerCase() ?? '';
          return name.contains(lowerQuery) || code.contains(lowerQuery);
        }).toList();
      }
    });
  }

  Future<void> _fetchStocks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await UretimlerVeritabaniServisi().receteGetir(
        widget.uretim.id,
      );
      if (mounted) {
        setState(() {
          _stocks = results;
          _filteredStocks = results;
          _productCount = results.length;
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
      // 1. Prepare Header Info
      final Map<String, dynamic> headerInfo = {
        'icon': widget.uretim.ad.isNotEmpty
            ? widget.uretim.ad[0].toUpperCase()
            : '?',
        'name': widget.uretim.ad,
        'code': widget.uretim.kod,
        'productCount': '($_productCount ${tr('common.product')})',
      };

      List<ExpandableRowData> rows = [];

      for (final stock in _filteredStocks) {
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
            ((stock['quantity'] as num?)?.toDouble() ?? 0),
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
        tr('productions.recipe.quantity'),
        tr('products.table.unit'),
        tr('products.table.features'),
      ];

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GenisletilebilirPrintPreviewScreen(
            title: '${tr('productions.recipe.title')} - ${widget.uretim.ad}',
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
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 760;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: isMobile ? double.infinity : 720,
        constraints: BoxConstraints(
          maxHeight: isMobile ? media.size.height * 0.9 : 750,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          isMobile ? 16 : 24,
          isMobile ? 16 : 28,
          isMobile ? 16 : 22,
        ),
        child: Column(
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
                        tr('productions.recipe.title'),
                        style: TextStyle(
                          fontSize: isMobile ? 19 : 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.uretim.kod} - ${widget.uretim.ad}',
                        maxLines: isMobile ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      Icons.print_outlined,
                      size: isMobile ? 20 : 22,
                      color: const Color(0xFF3C4043),
                    ),
                    onPressed: _handlePrint,
                    tooltip: tr('common.print'),
                  ),
                ),
                if (!isMobile)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Text(
                      tr('common.esc'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                  ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      Icons.close,
                      size: isMobile ? 20 : 22,
                      color: const Color(0xFF3C4043),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: tr('common.close'),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 14 : 20),

            // Info Card
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  widget.uretim.ad.isNotEmpty
                                      ? widget.uretim.ad[0].toUpperCase()
                                      : 'Ü',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.uretim.ad,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.uretim.kod,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                '${tr('common.product')}: $_productCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.uretim.birim,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Text(
                              widget.uretim.ad.isNotEmpty
                                  ? widget.uretim.ad[0].toUpperCase()
                                  : 'Ü',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.uretim.ad,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      widget.uretim.kod,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    widget.uretim.birim,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
                                tr('productions.recipe.title'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_productCount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr('common.product'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            SizedBox(height: isMobile ? 14 : 24),

            // Search Input
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                hintText: tr('products.search_placeholder'),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFFBDC1C6),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 14 : 20),

            // Stock List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredStocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Color(0xFFE0E0E0),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('products.no_products_found'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF606368),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount:
                                (_filteredStocks.length -
                                        (_currentPage - 1) * _rowsPerPage)
                                    .clamp(0, _rowsPerPage),
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Color(0xFFEEEEEE),
                            ),
                            itemBuilder: (context, index) {
                              final actualIndex =
                                  (_currentPage - 1) * _rowsPerPage + index;
                              if (actualIndex >= _filteredStocks.length) {
                                return const SizedBox.shrink();
                              }
                              final stock = _filteredStocks[actualIndex];
                              final quantity =
                                  (stock['quantity'] as num?)?.toDouble() ?? 0;
                              final totalStock =
                                  (stock['total_stock'] as num?)?.toDouble() ??
                                  0;
                              final unit = stock['unit']?.toString() ?? '';

                              if (isMobile) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stock['product_name']?.toString() ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        stock['product_code']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF606368),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (stock['barcode'] != null &&
                                          (stock['barcode'] as String)
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            stock['barcode'] as String,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE1F5FE),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${FormatYardimcisi.sayiFormatla(quantity, binlik: widget.genelAyarlar.binlikAyiraci, ondalik: widget.genelAyarlar.ondalikAyiraci, decimalDigits: widget.genelAyarlar.miktarOndalik)} $unit',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2C3E50),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE6F4EA),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${FormatYardimcisi.sayiFormatla(totalStock, binlik: widget.genelAyarlar.binlikAyiraci, ondalik: widget.genelAyarlar.ondalikAyiraci, decimalDigits: widget.genelAyarlar.miktarOndalik)} $unit',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E7E34),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE1F5FE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Color(0xFF0277BD),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stock['product_name']?.toString() ??
                                                '',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF202124),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                stock['product_code']
                                                        ?.toString() ??
                                                    '',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF606368),
                                                ),
                                              ),
                                              if (stock['barcode'] != null &&
                                                  (stock['barcode'] as String)
                                                      .isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFD1D5DB,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.qr_code,
                                                  size: 14,
                                                  color: Color(0xFF9CA3AF),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  stock['barcode'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF606368),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          tr('productions.recipe.quantity'),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${FormatYardimcisi.sayiFormatla(quantity, binlik: widget.genelAyarlar.binlikAyiraci, ondalik: widget.genelAyarlar.ondalikAyiraci, decimalDigits: widget.genelAyarlar.miktarOndalik)} $unit',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
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
                                        '${FormatYardimcisi.sayiFormatla(totalStock, binlik: widget.genelAyarlar.binlikAyiraci, ondalik: widget.genelAyarlar.ondalikAyiraci, decimalDigits: widget.genelAyarlar.miktarOndalik)} $unit',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E7E34),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Pagination Controls
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _currentPage > 1
                                    ? () => setState(() => _currentPage--)
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Text(
                                  tr('common.pagination.showing')
                                      .replaceAll(
                                        '{start}',
                                        '${(_currentPage - 1) * _rowsPerPage + 1}',
                                      )
                                      .replaceAll(
                                        '{end}',
                                        '${(_currentPage * _rowsPerPage).clamp(0, _filteredStocks.length)}',
                                      )
                                      .replaceAll(
                                        '{total}',
                                        '${_filteredStocks.length}',
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: const Color(0xFF606368),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed:
                                    _currentPage * _rowsPerPage <
                                        _filteredStocks.length
                                    ? () => setState(() => _currentPage++)
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
