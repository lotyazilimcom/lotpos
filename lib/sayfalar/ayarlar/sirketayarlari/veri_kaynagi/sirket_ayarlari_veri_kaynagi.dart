import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../../bilesenler/onay_dialog.dart';
import '../modeller/sirket_ayarlari_model.dart';

typedef OnSirketEdit = void Function(SirketAyarlariModel sirket);
typedef OnSirketDelete = void Function(SirketAyarlariModel sirket);
typedef OnSirketStatusChange =
    void Function(SirketAyarlariModel sirket, bool isActive);
typedef OnSirketSetDefault = void Function(SirketAyarlariModel sirket);

class SirketAyarlariVeriKaynagi extends DataGridSource {
  final BuildContext context;
  final OnSirketEdit onEdit;
  final OnSirketDelete onDelete;
  final OnSirketStatusChange onStatusChange;
  final OnSirketSetDefault onSetDefault;

  List<SirketAyarlariModel> _sirketler = [];
  List<DataGridRow> _dataGridRows = [];

  final Set<int> _selectedIds = {};

  SirketAyarlariVeriKaynagi({
    required this.context,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onSetDefault,
    List<SirketAyarlariModel>? sirketler,
  }) {
    if (sirketler != null) {
      _sirketler = sirketler;
      _buildDataGridRows();
    }
  }

  void updateData(List<SirketAyarlariModel> sirketler) {
    _sirketler = sirketler;
    _buildDataGridRows();
    notifyListeners();
  }

  void _buildDataGridRows() {
    _dataGridRows = _sirketler.map<DataGridRow>((sirket) {
      return DataGridRow(
        cells: [
          const DataGridCell<bool>(columnName: 'checkbox', value: false),
          DataGridCell<int>(columnName: 'id', value: sirket.id),
          DataGridCell<String>(columnName: 'kod', value: sirket.kod),
          DataGridCell<String>(columnName: 'ad', value: sirket.ad),
          DataGridCell<bool>(
            columnName: 'varsayilan',
            value: sirket.varsayilanMi,
          ),
          DataGridCell<bool>(columnName: 'durum', value: sirket.aktifMi),
          DataGridCell<bool>(
            columnName: 'duzenlenebilir',
            value: sirket.duzenlenebilirMi,
          ),
          DataGridCell<List<String>>(
            columnName: 'baslik_sayisi',
            value: sirket.ustBilgiSatirlari,
          ),
          DataGridCell<SirketAyarlariModel>(
            columnName: 'actions',
            value: sirket,
          ),
        ],
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final sirket = row.getCells().last.value as SirketAyarlariModel;
    final isSelected = _selectedIds.contains(sirket.id);

    return DataGridRowAdapter(
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.white,
      cells: row.getCells().map<Widget>((dataGridCell) {
        Alignment alignment = Alignment.centerLeft;
        if (dataGridCell.columnName == 'id' ||
            dataGridCell.columnName == 'duzenlenebilir' ||
            dataGridCell.columnName == 'checkbox' ||
            dataGridCell.columnName == 'actions') {
          alignment = Alignment.center;
        }
        return Container(
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: _buildCellWidget(dataGridCell, sirket),
        );
      }).toList(),
    );
  }

  Widget _buildCellWidget(DataGridCell cell, SirketAyarlariModel sirket) {
    switch (cell.columnName) {
      case 'checkbox':
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Checkbox(
            value: isSelected(sirket.id),
            onChanged: (value) {
              toggleSelection(sirket.id);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
          ),
        );
      case 'id':
        return Text(
          cell.value.toString(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        );
      case 'kod':
        return Text(
          cell.value.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        );
      case 'ad':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sirket.ustBilgiLogosu != null &&
                sirket.ustBilgiLogosu!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Image.memory(
                  base64Decode(sirket.ustBilgiLogosu!),
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            Text(
              cell.value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        );
      case 'varsayilan':
        return sirket.varsayilanMi
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tr('settings.company.column.default'),
                  style: const TextStyle(
                    color: Color(0xFF1E7E34),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const SizedBox.shrink();
      case 'durum':
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sirket.aktifMi
                  ? const Color(0xFFE6F4EA)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              sirket.aktifMi
                  ? tr('language.status.active')
                  : tr('language.status.inactive'),
              style: TextStyle(
                color: sirket.aktifMi
                    ? const Color(0xFF1E7E34)
                    : const Color(0xFF757575),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 'duzenlenebilir':
        return Icon(
          sirket.duzenlenebilirMi ? Icons.check_circle : Icons.cancel,
          color: sirket.duzenlenebilirMi
              ? const Color(0xFF1E7E34)
              : const Color(0xFFEA4335),
          size: 20,
        );
      case 'baslik_sayisi':
        final lines = cell.value as List<String>;
        if (lines.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines
                .map(
                  (line) => Text(
                    line,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
                .toList(),
          ),
        );

      case 'actions':
        return _buildPopupMenu(sirket);
      default:
        return Text(cell.value.toString());
    }
  }

  Widget _buildPopupMenu(SirketAyarlariModel sirket) {
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
            constraints: const BoxConstraints(minWidth: 190),
            splashRadius: 20,
            offset: const Offset(0, 8),
            tooltip: tr('language.table.menu'),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'edit',
                enabled: sirket.duzenlenebilirMi,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: sirket.duzenlenebilirMi
                          ? const Color(0xFF2C3E50)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('common.edit'),
                      style: TextStyle(
                        color: sirket.duzenlenebilirMi
                            ? const Color(0xFF2C3E50)
                            : Colors.grey.shade400,
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
                value: 'set_default',
                enabled: !sirket.varsayilanMi,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: sirket.varsayilanMi
                          ? Colors.grey.shade400
                          : const Color(0xFF1E7E34),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('settings.company.set_default'),
                      style: TextStyle(
                        color: sirket.varsayilanMi
                            ? Colors.grey.shade400
                            : const Color(0xFF1E7E34),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
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
                          ? tr('language.menu.deactivate')
                          : tr('language.menu.activate'),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
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
                onEdit(sirket);
              } else if (value == 'set_default') {
                onSetDefault(sirket);
              } else if (value == 'deactivate' || value == 'activate') {
                onStatusChange(sirket, value == 'activate');
              } else if (value == 'delete') {
                if (sirket.varsayilanMi) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr('settings.company.delete.protected.message'),
                      ),
                    ),
                  );
                  return;
                }
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.35),
                  builder: (context) => OnayDialog(
                    baslik: tr('settings.company.delete.dialog.title.single'),
                    mesaj: tr(
                      'settings.company.delete.dialog.message.single',
                    ).replaceAll('{name}', sirket.ad),
                    onayButonMetni: tr('common.delete'),
                    iptalButonMetni: tr('common.cancel'),
                    isDestructive: true,
                    onOnay: () => onDelete(sirket),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  bool isSelected(int? id) => id != null && _selectedIds.contains(id);

  void toggleSelection(int? id) {
    if (id == null) return;
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(bool select) {
    _selectedIds.clear();
    if (select) {
      for (var sirket in _sirketler) {
        if (sirket.id != null) {
          _selectedIds.add(sirket.id!);
        }
      }
    }
    notifyListeners();
  }

  int get selectedCount => _selectedIds.length;

  bool? get selectAllState {
    if (_selectedIds.isEmpty) return false;
    if (_selectedIds.length == _sirketler.length) return true;
    return null;
  }

  List<int> get selectedIds => _selectedIds.toList();

  bool get hasCoreCompanySelected {
    return _sirketler
        .where((s) => _selectedIds.contains(s.id))
        .any((s) => s.varsayilanMi);
  }

  void applyPagination(int page, int rowsPerPage) {
    // Pagination logic can be implemented here if needed
  }
}
