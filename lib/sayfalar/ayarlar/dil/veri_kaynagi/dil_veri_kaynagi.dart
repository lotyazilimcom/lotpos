import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../dil_ekle_dialog.dart';
import '../ceviri_duzenle_dialog.dart';
import '../../../../bilesenler/onay_dialog.dart';
import '../modeller/dil_model.dart';

class DilDataSource extends DataGridSource {
  final BuildContext context;

  DilDataSource({required this.context, required List<DilModel> diller}) {
    updateData(diller);
  }

  List<DataGridRow> _diller = [];
  List<DilModel> _dillerData = [];
  final Set<int> _selectedIds = {};
  int _currentPage = 1;
  int _rowsPerPage = 25;

  void updateData(List<DilModel> diller) {
    _dillerData = diller;
    _updatePaginatedRows();
  }

  void applyPagination(int page, int rowsPerPage) {
    _currentPage = page;
    _rowsPerPage = rowsPerPage;
    _updatePaginatedRows();
  }

  void _updatePaginatedRows() {
    int startIndex = (_currentPage - 1) * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    if (startIndex >= _dillerData.length) {
      startIndex = 0;
      endIndex = _rowsPerPage;
    }

    final paginatedData = _dillerData.sublist(
      startIndex,
      endIndex.clamp(0, _dillerData.length),
    );

    _diller = paginatedData
        .map<DataGridRow>(
          (e) => DataGridRow(
            cells: [
              DataGridCell<bool>(columnName: 'checkbox', value: false),
              DataGridCell<int>(columnName: 'id', value: e.id),
              DataGridCell<DilModel>(columnName: 'name', value: e),
              DataGridCell<bool>(columnName: 'default', value: e.isDefault),
              DataGridCell<String>(columnName: 'actions', value: ''),
              DataGridCell<bool>(columnName: 'status', value: e.isActive),
              DataGridCell<DilModel>(columnName: 'menu', value: e),
            ],
          ),
        )
        .toList();

    notifyListeners();
  }

  @override
  Future<void> sort() async {
    if (sortedColumns.isEmpty) {
      _diller = _dillerData
          .map<DataGridRow>(
            (e) => DataGridRow(
              cells: [
                DataGridCell<bool>(columnName: 'checkbox', value: false),
                DataGridCell<int>(columnName: 'id', value: e.id),
                DataGridCell<DilModel>(columnName: 'name', value: e),
                DataGridCell<bool>(columnName: 'default', value: e.isDefault),
                DataGridCell<String>(columnName: 'actions', value: ''),
                DataGridCell<bool>(columnName: 'status', value: e.isActive),
                DataGridCell<DilModel>(columnName: 'menu', value: e),
              ],
            ),
          )
          .toList();
      notifyListeners();
      return;
    }

    final sortColumn = sortedColumns.first;
    _performSort(sortColumn.name, sortColumn.sortDirection);
    _updatePaginatedRows();
    notifyListeners();
  }

  @override
  Future<void> performSorting(List<DataGridRow> rows) async {
    // Sorting is handled manually in sort() and _updatePaginatedRows()
    // We override this to prevent the default sorting which fails on bool types
  }

  void _performSort(String name, DataGridSortDirection direction) {
    if (direction == DataGridSortDirection.ascending) {
      _dillerData.sort((a, b) => _compareModels(a, b, name));
    } else {
      _dillerData.sort((b, a) => _compareModels(a, b, name));
    }
  }

  int _compareModels(DilModel a, DilModel b, String columnName) {
    if (columnName == 'id') {
      return a.id.compareTo(b.id);
    } else if (columnName == 'name') {
      return a.name.compareTo(b.name);
    } else if (columnName == 'default') {
      return (a.isDefault ? 1 : 0).compareTo(b.isDefault ? 1 : 0);
    } else if (columnName == 'status') {
      return (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
    }
    return 0;
  }

  @override
  List<DataGridRow> get rows => _diller;

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
      _selectedIds.addAll(_dillerData.map((e) => e.id));
    } else {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  bool get isAllSelected =>
      _dillerData.isNotEmpty && _selectedIds.length == _dillerData.length;

  bool? get selectAllState {
    if (_selectedIds.isEmpty) return false;
    if (_selectedIds.length == _dillerData.length) return true;
    return null;
  }

  bool isSelected(int id) => _selectedIds.contains(id);
  int get selectedCount => _selectedIds.length;
  List<int> get selectedIds => _selectedIds.toList();

  bool get hasCoreLanguageSelected {
    return _dillerData
        .where((d) => _selectedIds.contains(d.id))
        .any((d) => ['tr', 'en', 'ar'].contains(d.code));
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        Alignment alignment = Alignment.centerLeft;
        if (dataGridCell.columnName == 'id' ||
            dataGridCell.columnName == 'menu' ||
            dataGridCell.columnName == 'status' ||
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
      return Text(
        cell.value.toString(),
        style: const TextStyle(color: Colors.black87, fontSize: 15),
      );
    } else if (cell.columnName == 'name') {
      final DilModel dil = cell.value;
      return Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE0E7EC),
            child: Text(
              dil.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dil.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),
              Text(
                dil.code,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ],
      );
    } else if (cell.columnName == 'default') {
      final bool isDefault = cell.value;
      if (isDefault) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4EA),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tr('language.default'),
            style: const TextStyle(
              color: Color(0xFF1E7E34),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      } else {
        final DilModel dil = row
            .getCells()
            .firstWhere((c) => c.columnName == 'name')
            .value;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: OutlinedButton(
            onPressed: () {
              Provider.of<CeviriServisi>(
                context,
                listen: false,
              ).dilDegistir(dil.code);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF28A745)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              tr('language.setAsDefault'),
              style: const TextStyle(
                color: Color(0xFF28A745),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }
    } else if (cell.columnName == 'actions') {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: OutlinedButton(
              onPressed: () {
                final DilModel dil = row
                    .getCells()
                    .firstWhere((c) => c.columnName == 'name')
                    .value;
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.35),
                  builder: (context) => CeviriDuzenleDialog(
                    languageName: dil.name,
                    languageCode: dil.code,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2C3E50)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                tr('language.editTranslations'),
                style: const TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: OutlinedButton(
              onPressed: () {
                final DilModel dil = row
                    .getCells()
                    .firstWhere((c) => c.columnName == 'name')
                    .value;
                _exportLanguage(dil);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF9F1C)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                tr('language.exportLanguage'),
                style: const TextStyle(
                  color: Color(0xFFFF9F1C),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (cell.columnName == 'status') {
      final bool isActive = cell.value;
      return Container(
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
              isActive
                  ? tr('language.status.active')
                  : tr('language.status.inactive'),
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
      );
    } else if (cell.columnName == 'menu') {
      final DilModel dil = cell.value;
      return _buildPopupMenu(dil);
    }
    return const SizedBox.shrink();
  }

  Widget _buildPopupMenu(DilModel dil) {
    final bool isCoreLanguage = ['tr', 'en', 'ar'].contains(dil.code);

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
                enabled: !isCoreLanguage,
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
                      color: isCoreLanguage
                          ? Colors.grey.shade400
                          : const Color(0xFF2C3E50),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('common.edit'),
                      style: TextStyle(
                        color: isCoreLanguage
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
                value: dil.isActive ? 'deactivate' : 'activate',
                enabled: !dil.isDefault,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      dil.isActive
                          ? Icons.toggle_on_outlined
                          : Icons.toggle_off_outlined,
                      size: 20,
                      color: dil.isDefault
                          ? Colors.grey.shade400
                          : const Color(0xFF2C3E50),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      dil.isActive
                          ? tr('language.menu.deactivate')
                          : tr('language.menu.activate'),
                      style: TextStyle(
                        color: dil.isDefault
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
                enabled: !isCoreLanguage,
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
                      color: isCoreLanguage
                          ? Colors.grey.shade400
                          : const Color(0xFFEA4335),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('common.delete'),
                      style: TextStyle(
                        color: isCoreLanguage
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
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.35),
                  builder: (context) =>
                      DilEkleDialog(editLanguageCode: dil.code),
                );
              } else if (value == 'deactivate') {
                Provider.of<CeviriServisi>(
                  context,
                  listen: false,
                ).dilPasifYap(dil.code);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${dil.name} ${tr('language.status.inactive')}',
                    ),
                  ),
                );
              } else if (value == 'activate') {
                Provider.of<CeviriServisi>(
                  context,
                  listen: false,
                ).dilAktifYap(dil.code);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${dil.name} ${tr('language.status.active')}',
                    ),
                  ),
                );
              } else if (value == 'delete') {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.35),
                  builder: (context) => OnayDialog(
                    baslik: tr('common.delete'),
                    mesaj:
                        '${dil.name} ${tr('language.dialog.delete.confirm')}',
                    onayButonMetni: tr('common.delete'),
                    iptalButonMetni: tr('common.cancel'),
                    isDestructive: true,
                    onOnay: () {
                      Provider.of<CeviriServisi>(
                        context,
                        listen: false,
                      ).dilSil(dil.code);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${dil.name} ${tr('common.delete')}'),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportLanguage(DilModel dil) async {
    final ceviriServisi = Provider.of<CeviriServisi>(context, listen: false);
    final translations = await ceviriServisi.getCevirilerAsync(dil.code);

    if (translations == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('common.error.translation_not_found'))),
      );
      return;
    }

    final Map<String, dynamic> jsonContent = {
      "language": {
        "name": dil.name,
        "short_form": dil.code,
        "language_code": _getFullCode(dil.code),
        "text_direction": dil.code == 'ar' ? 'rtl' : 'ltr',
        "text_editor_lang": dil.code,
      },
      "translations": translations.entries
          .map((e) => {"label": e.key, "translation": e.value})
          .toList(),
    };

    final String jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonContent);
    final String fileName = '${dil.name}.json';

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastPath = prefs.getString('last_export_path');

      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: fileName,
        initialDirectory: lastPath,
        acceptedTypeGroups: [
          XTypeGroup(
            label: tr('common.json'),
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );

      if (result == null) {
        return;
      }

      final String path = result.path;
      final File file = File(path);
      await file.writeAsString(jsonString);

      final String parentDir = file.parent.path;
      await prefs.setString('last_export_path', parentDir);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'common.success.export_path',
              ).replaceAll('{name}', dil.name).replaceAll('{path}', path),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('common.error.generic')}$e')),
        );
      }
    }
  }

  String _getFullCode(String shortCode) {
    switch (shortCode) {
      case 'tr':
        return 'tr-TR';
      case 'en':
        return 'en-US';
      case 'ar':
        return 'ar-SA';
      default:
        return '$shortCode-$shortCode';
    }
  }
}
