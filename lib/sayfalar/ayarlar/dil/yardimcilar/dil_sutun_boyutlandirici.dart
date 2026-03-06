import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../modeller/dil_model.dart';

class DilColumnSizer extends ColumnSizer {
  static const double _avatarSize = 32;
  static const double _avatarSpacing = 12;

  @override
  double computeCellWidth(
    GridColumn column,
    DataGridRow row,
    Object? cellValue,
    TextStyle textStyle,
  ) {
    if (column.columnName == 'name' && cellValue is DilModel) {
      final String text = '${cellValue.name} ${cellValue.code}';
      final double textWidth = super.computeCellWidth(
        column,
        row,
        text,
        textStyle,
      );
      return textWidth + _avatarSize + _avatarSpacing;
    }

    return super.computeCellWidth(column, row, cellValue, textStyle);
  }

  @override
  double computeHeaderCellWidth(GridColumn column, TextStyle style) {
    final double baseWidth = super.computeHeaderCellWidth(column, style);

    if (column.columnName == 'name') {
      return baseWidth + _avatarSize + _avatarSpacing;
    }

    return baseWidth;
  }
}
