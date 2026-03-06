import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../modeller/depo_model.dart';

class DepoDataSource extends DataGridSource {
  final BuildContext context;

  DepoDataSource({required this.context, required List<DepoModel> depolar}) {
    updateData(depolar);
  }

  List<DataGridRow> _depolar = [];
  List<DepoModel> _depolarData = [];
  final Set<int> _selectedIds = {};

  void updateData(List<DepoModel> depolar) {
    _depolarData = depolar;
    _updatePaginatedRows();
  }

  List<DepoModel> get filteredDepolar => _depolarData;

  void _updatePaginatedRows() {
    final paginatedData = _depolarData;

    _depolar = paginatedData
        .map<DataGridRow>(
          (e) => DataGridRow(
            cells: [
              DataGridCell<bool>(columnName: 'checkbox', value: false),
              DataGridCell<int>(columnName: 'id', value: e.id),
              DataGridCell<DepoModel>(columnName: 'code', value: e),
              DataGridCell<DepoModel>(columnName: 'name', value: e),
              DataGridCell<String>(columnName: 'address', value: e.adres),
              DataGridCell<String>(columnName: 'responsible', value: e.sorumlu),
              DataGridCell<String>(columnName: 'phone', value: e.telefon),
              DataGridCell<bool>(columnName: 'status', value: e.aktifMi),
              DataGridCell<DepoModel>(columnName: 'actions', value: e),
            ],
          ),
        )
        .toList();

    notifyListeners();
  }

  @override
  Future<void> sort() async {
    // Sorting is handled server-side by the parent widget.
    // This method is called by the DataGrid, but we don't need to do anything here
    // because the parent widget listens to onSort and fetches new data.
  }

  @override
  Future<void> performSorting(List<DataGridRow> rows) async {
    // Sorting is handled server-side.
  }

  @override
  List<DataGridRow> get rows => _depolar;

  void toggleSelection(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(bool select) {
    if (select) {
      _selectedIds.clear();
      _selectedIds.addAll(_depolarData.map((e) => e.id));
    } else {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  bool get isAllSelected =>
      _depolarData.isNotEmpty && _selectedIds.length == _depolarData.length;

  bool? get selectAllState {
    if (_selectedIds.isEmpty) return false;
    if (_selectedIds.length == _depolarData.length) return true;
    return null;
  }

  bool isSelected(int id) => _selectedIds.contains(id);
  int get selectedCount => _selectedIds.length;
  List<int> get selectedIds => _selectedIds.toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        Alignment alignment = Alignment.centerLeft;
        if (dataGridCell.columnName == 'id' ||
            dataGridCell.columnName == 'checkbox') {
          alignment = Alignment.center;
        }
        return Container(
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _buildCellWidget(dataGridCell, row),
        );
      }).toList(),
    );
  }

  Widget _buildCellWidget(DataGridCell cell, DataGridRow row) {
    if (cell.columnName == 'checkbox') {
      final int id = row
          .getCells()
          .firstWhere((c) => c.columnName == 'id')
          .value;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Checkbox(
          value: _selectedIds.contains(id),
          onChanged: (value) {
            toggleSelection(id);
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
        ),
      );
    } else if (cell.columnName == 'id') {
      return Align(
        alignment: Alignment.center,
        child: Text(
          cell.value.toString(),
          style: const TextStyle(color: Colors.black87, fontSize: 15),
        ),
      );
    } else if (cell.columnName == 'code') {
      final DepoModel depo = cell.value;
      return Text(
        depo.kod,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 15,
        ),
      );
    } else if (cell.columnName == 'name') {
      final DepoModel depo = cell.value;
      return Text(
        depo.ad,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          fontSize: 15,
        ),
      );
    } else if (cell.columnName == 'address') {
      return Text(
        cell.value.toString(),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (cell.columnName == 'responsible') {
      return Text(
        cell.value.toString(),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      );
    } else if (cell.columnName == 'phone') {
      return Text(
        cell.value.toString(),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      );
    } else if (cell.columnName == 'status') {
      final bool isActive = cell.value;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE6F4EA) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.circle,
                size: 5,
                color: isActive
                    ? const Color(0xFF28A745)
                    : const Color(0xFF757575),
              ),
              const SizedBox(width: 4),
              Text(
                isActive ? tr('common.active') : tr('common.passive'),
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFF1E7E34)
                      : const Color(0xFF757575),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (cell.columnName == 'actions') {
      final DepoModel depo = cell.value;
      return _buildPopupMenu(depo);
    }
    return const SizedBox.shrink();
  }

  Widget _buildPopupMenu(DepoModel depo) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Builder(
        builder: (context) => Theme(
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
            icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 160),
            splashRadius: 20,
            offset: const Offset(0, 8),
            tooltip: tr('common.actions'),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'edit',
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
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
                value: 'delete',
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFEA4335),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('common.delete'),
                      style: const TextStyle(
                        color: Color(0xFFEA4335),
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
                // Edit dialog
              } else if (value == 'delete') {
                // Delete confirmation
              }
            },
          ),
        ),
      ),
    );
  }
}
