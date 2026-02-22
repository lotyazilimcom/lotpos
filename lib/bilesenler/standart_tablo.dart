import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

class StandartTablo extends StatefulWidget {
  final String title;
  final DataGridSource source;
  final List<GridColumn> columns;
  final List<Widget> actions;
  final Function(String) onSearch;
  final Function(int page, int rowsPerPage) onPageChanged;
  final int totalRecords;
  final bool isLoading;
  final String persistenceKey;
  final ColumnSizer? columnSizer;
  final Widget? selectionWidget;

  const StandartTablo({
    super.key,
    required this.title,
    required this.source,
    required this.columns,
    this.actions = const [],
    required this.onSearch,
    required this.onPageChanged,
    required this.totalRecords,
    this.isLoading = false,
    required this.persistenceKey,
    this.columnSizer,
    this.selectionWidget,
  });

  @override
  State<StandartTablo> createState() => _StandartTabloState();
}

class _StandartTabloState extends State<StandartTablo> {
  final TextEditingController _searchController = TextEditingController();
  int _rowsPerPage = 25;
  int _currentPage = 1;
  final Map<String, double> _columnWidths = {};
  Timer? _resizeDebounce;
  Timer? _searchDebounce;
  final List<int> _rowsPerPageOptions = [10, 25, 50, 100, 250, 500];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      if (_searchDebounce?.isActive ?? false) {
        _searchDebounce!.cancel();
      }
      _searchDebounce = Timer(
        const Duration(milliseconds: 500),
        () => widget.onSearch(query),
      );
    });
    _loadColumnWidths();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _resizeDebounce?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadColumnWidths() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var col in widget.columns) {
        final double? savedWidth = prefs.getDouble(
          '${widget.persistenceKey}_column_width_${col.columnName}',
        );
        if (savedWidth != null) {
          _columnWidths[col.columnName] = savedWidth;
        }
      }
    });
  }

  void _saveColumnWidth(String columnName, double width) {
    if (_resizeDebounce?.isActive ?? false) _resizeDebounce!.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        '${widget.persistenceKey}_column_width_$columnName',
        width,
      );
    });
  }

  void _changePage(int page) {
    setState(() {
      _currentPage = page;
    });
    widget.onPageChanged(_currentPage, _rowsPerPage);
  }

  void _changeRowsPerPage(int? value) {
    if (value != null) {
      setState(() {
        _rowsPerPage = value;
        _currentPage = 1; // Reset to first page
      });
      widget.onPageChanged(_currentPage, _rowsPerPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 20),

        // Toolbar
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rows Per Page Dropdown & Selection Widget
            Column(
	              crossAxisAlignment: CrossAxisAlignment.start,
	              children: [
	                MouseRegion(
	                  cursor: SystemMouseCursors.click,
	                  hitTestBehavior: HitTestBehavior.deferToChild,
	                  child: Container(
	                    height: 40,
	                    padding: const EdgeInsets.symmetric(horizontal: 12),
	                    decoration: BoxDecoration(
	                      color: Colors.white,
	                      border: Border.all(color: Colors.grey.shade300),
	                      borderRadius: BorderRadius.circular(8),
	                      boxShadow: [
	                        BoxShadow(
	                          color: Colors.black.withValues(alpha: 0.05),
	                          blurRadius: 2,
	                          offset: const Offset(0, 1),
	                        ),
	                      ],
	                    ),
	                    child: DropdownButtonHideUnderline(
	                      child: DropdownButton<int>(
	                        mouseCursor: WidgetStateMouseCursor.clickable,
	                        dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
	                        value: _rowsPerPage,
	                        icon: const Icon(
	                          Icons.keyboard_arrow_down,
	                          size: 20,
	                          color: Color(0xFF606368),
	                        ),
	                        style: const TextStyle(
	                          fontWeight: FontWeight.w600,
	                          color: Color(0xFF333333),
	                          fontSize: 14,
	                        ),
	                        dropdownColor: Colors.white,
	                        borderRadius: BorderRadius.circular(8),
	                        elevation: 4,
	                        onChanged: _changeRowsPerPage,
	                        items: _rowsPerPageOptions.map((e) {
	                          return DropdownMenuItem(value: e, child: Text('$e'));
	                        }).toList(),
	                      ),
	                    ),
	                  ),
	                ),
	                if (widget.selectionWidget != null)
	                  Padding(
	                    padding: const EdgeInsets.only(top: 8.0),
	                    child: widget.selectionWidget!,
	                  ),
              ],
            ),
            const Spacer(),

            // Search Bar
            SizedBox(
              width: 250,
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: tr('common.search'),
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.search, color: Colors.grey),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2C3E50)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Actions
            ...widget.actions,
          ],
        ),
        const SizedBox(height: 20),

        // DataGrid
        Expanded(
          child: CheckboxTheme(
            data: CheckboxThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 0.8),
            ),
            child: SfDataGridTheme(
              data: SfDataGridThemeData(
                headerColor: Colors.white,
                gridLineColor: Colors.grey.shade200,
                gridLineStrokeWidth: 1,
                selectionColor: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                currentCellStyle: const DataGridCurrentCellStyle(
                  borderWidth: 0,
                  borderColor: Colors.transparent,
                ),
              ),
              child: SfDataGrid(
                source: widget.source,
                allowSorting: true,
                allowColumnsResizing: true,
                onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                  setState(() {
                    _columnWidths[details.column.columnName] = details.width;
                  });
                  _saveColumnWidth(details.column.columnName, details.width);
                  return true;
                },
                rowHeight: 60,
                columnSizer: widget.columnSizer,
                columnWidthMode: ColumnWidthMode.auto, // Smart sizing
                columnWidthCalculationRange:
                    ColumnWidthCalculationRange.allRows,
                headerGridLinesVisibility: GridLinesVisibility.none,
                gridLinesVisibility: GridLinesVisibility.horizontal,
                selectionMode: SelectionMode.single,
                showCheckboxColumn: false,
                columns: widget.columns.map((col) {
                  // Wrap label with MouseRegion for pointer cursor
                  final Widget labelWithCursor = MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: col.label,
                  );

                  double width = col.width;
                  if (_columnWidths.containsKey(col.columnName)) {
                    width = _columnWidths[col.columnName]!;
                  }

                  return GridColumn(
                    columnName: col.columnName,
                    label: labelWithCursor,
                    width: width,
                    allowSorting: col.allowSorting,
                    minimumWidth: col.minimumWidth,
                    maximumWidth: col.maximumWidth,
                    columnWidthMode: col.columnWidthMode,
                    visible: col.visible,
                    autoFitPadding: col.autoFitPadding,
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Pagination Footer
        _buildPaginationFooter(),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    if (widget.totalRecords == 0) return const SizedBox.shrink();

    final int effectiveRowsPerPage = _rowsPerPage;
    final int totalPages = effectiveRowsPerPage > 0
        ? (widget.totalRecords / effectiveRowsPerPage).ceil()
        : 1;

    final int startRecord = (_currentPage - 1) * effectiveRowsPerPage + 1;
    final int endRecord = (_currentPage * effectiveRowsPerPage).clamp(
      0,
      widget.totalRecords,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tr('common.pagination.showing')
                .replaceAll('{start}', '$startRecord')
                .replaceAll('{end}', '$endRecord')
                .replaceAll('{total}', '${widget.totalRecords}'),
            style: const TextStyle(
              color: Color(0xFF606368),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _buildPageButton(
                icon: Icons.keyboard_double_arrow_left,
                onTap: _currentPage > 1 ? () => _changePage(1) : null,
              ),
              const SizedBox(width: 8),
              _buildPageButton(
                icon: Icons.keyboard_arrow_left,
                onTap: _currentPage > 1
                    ? () => _changePage(_currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 8),
              ..._buildPageNumbers(totalPages),
              const SizedBox(width: 8),
              _buildPageButton(
                icon: Icons.keyboard_arrow_right,
                onTap: _currentPage < totalPages
                    ? () => _changePage(_currentPage + 1)
                    : null,
              ),
              const SizedBox(width: 8),
              _buildPageButton(
                icon: Icons.keyboard_double_arrow_right,
                onTap: _currentPage < totalPages
                    ? () => _changePage(totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> buttons = [];

    int startPage = _currentPage - 2;
    int endPage = _currentPage + 2;

    if (startPage < 1) {
      endPage += (1 - startPage);
      startPage = 1;
    }

    if (endPage > totalPages) {
      startPage -= (endPage - totalPages);
      endPage = totalPages;
    }

    startPage = startPage.clamp(1, totalPages);
    endPage = endPage.clamp(1, totalPages);

    for (int i = startPage; i <= endPage; i++) {
      if (i > 1) buttons.add(const SizedBox(width: 8));
      buttons.add(
        _buildPageButton(
          text: '$i',
          isActive: i == _currentPage,
          onTap: () => _changePage(i),
        ),
      );
    }
    return buttons;
  }

  Widget _buildPageButton({
    String? text,
    IconData? icon,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 32),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2C3E50) : Colors.white,
            border: Border.all(
              color: isActive ? const Color(0xFF2C3E50) : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: text != null
              ? Text(
                  text,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF606368),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                )
              : Icon(
                  icon,
                  size: 18,
                  color: onTap != null
                      ? const Color(0xFF606368)
                      : Colors.grey.shade300,
                ),
        ),
      )),
    );
  }
}
