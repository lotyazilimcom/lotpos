import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xcel;
import 'package:pdf/widgets.dart' as pw;
import 'genisletilebilir_print_service.dart';

class GenisletilebilirExcelService {
  static Future<List<int>> generateExcel({
    required String title,
    required List<String> headers,
    required List<ExpandableRowData> data,
    bool printFeatures = true,
    String? dateInterval,
  }) async {
    // 1. Create a WorkBook
    final xcel.Workbook workbook = xcel.Workbook();
    final xcel.Worksheet sheet = workbook.worksheets[0];

    // 2. Global Styles
    final xcel.Style headerStyle = workbook.styles.add('HeaderStyle');
    headerStyle.fontName = 'Calibri';
    headerStyle.bold = true;
    headerStyle.fontSize = 11;
    headerStyle.hAlign = xcel.HAlignType.left;
    headerStyle.vAlign = xcel.VAlignType.center;
    headerStyle.backColor = '#F2F2F2';
    headerStyle.borders.bottom.lineStyle = xcel.LineStyle.thin;
    headerStyle.borders.bottom.color = '#BFBFBF';

    final xcel.Style mainRowStyle = workbook.styles.add('MainRowStyle');
    mainRowStyle.fontName = 'Calibri';
    mainRowStyle.fontSize = 10;
    mainRowStyle.vAlign = xcel.VAlignType.center;
    mainRowStyle.borders.bottom.lineStyle = xcel.LineStyle.thin;
    mainRowStyle.borders.bottom.color = '#E0E0E0';

    final xcel.Style detailLabelStyle = workbook.styles.add('DetailLabelStyle');
    detailLabelStyle.fontName = 'Calibri';
    detailLabelStyle.bold = true;
    detailLabelStyle.fontSize = 9;
    detailLabelStyle.fontColor = '#666666';

    final xcel.Style detailValueStyle = workbook.styles.add('DetailValueStyle');
    detailValueStyle.fontName = 'Calibri';
    detailValueStyle.fontSize = 9;

    // 3. Document Title
    sheet.getRangeByName('A1').setText(title);
    sheet.getRangeByName('A1').cellStyle.bold = true;
    sheet.getRangeByName('A1').cellStyle.fontSize = 14;

    if (dateInterval != null) {
      sheet.getRangeByName('A2').setText(dateInterval);
      sheet.getRangeByName('A2').cellStyle.italic = true;
      sheet.getRangeByName('A2').cellStyle.fontSize = 10;
      sheet.getRangeByName('A2').cellStyle.fontColor = '#666666';
    }

    // 4. Headers (Row 4)
    int currentRow = 4;
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(currentRow, i + 1).setText(headers[i]);
      sheet.getRangeByIndex(currentRow, i + 1).cellStyle = headerStyle;
      // Set initial column widths
      sheet.setColumnWidthInPixels(i + 1, i == 2 ? 200 : 100);
    }
    currentRow++;

    // 5. Data Rows
    for (var item in data) {
      // A. Main Row
      for (int i = 0; i < item.mainRow.length; i++) {
        final cell = sheet.getRangeByIndex(currentRow, i + 1);
        cell.setText(item.mainRow[i]);
        cell.cellStyle = mainRowStyle;

        // Highlight Name column just like PDF
        if (i == 2) cell.cellStyle.bold = true;
      }
      currentRow++;

      // Features Check
      bool hasDetails =
          (printFeatures &&
              (item.details.isNotEmpty ||
                  (item.resolvedImages != null &&
                      item.resolvedImages!.isNotEmpty))) ||
          item.transactions != null;

      if (hasDetails) {
        // Indent for hierarchy visual
        int startCol = 2; // Start from column B

        // B. Details (Key-Value)
        if (printFeatures && item.details.isNotEmpty) {
          int detailRow = currentRow;
          int colIndex = startCol;

          item.details.forEach((key, value) {
            // Write Key
            final keyCell = sheet.getRangeByIndex(detailRow, colIndex);
            keyCell.setText('$key:');
            keyCell.cellStyle = detailLabelStyle;

            // Write Value (Next cell or concatenated? Let's use next cell for clean data)
            // But to save space, let's put "Key: Value" in one cell or Key in one, Value in next.
            // User wants "Functional", so separate cells is better for filtering if they ever wanted,
            // but for "Preview" look, "Key: Value" in one cell might be cleaner.
            // Let's go with Key in one cell, Value in next, then wrap.

            // Actually, let's stack them vertically or grid-like.
            // PDF uses a Wrap. Excel is grid.
            // Let's simple format:
            // | (Empty) | Key | Value | Key | Value | ...

            // To prevent messy grid, let's just list them downwards indented.
            final valCell = sheet.getRangeByIndex(detailRow, colIndex + 1);
            valCell.setText(value); // Value in next column
            valCell.cellStyle = detailValueStyle;

            // Move to next pair (simulate Wrap with 2 pairs per row maybe?)
            // colIndex += 2;
            // if (colIndex > 6) { colIndex = startCol; detailRow++; }

            // Simplest: List them one by one vertically to ensure nothing overlaps.
            // Or comma separated?
            // PDF: Grid 120 width.
            // Let's do: Key (Col B) - Value (Col C)
            detailRow++;
          });

          // If we advanced rows
          currentRow = detailRow;
        }

        // C. Images
        if (printFeatures &&
            item.resolvedImages != null &&
            item.resolvedImages!.isNotEmpty) {
          // Insert images in a row
          int imgCol = startCol;
          // We need to ensure row height fits images
          sheet.setRowHeightInPixels(currentRow, 50);

          for (var img in item.resolvedImages!.take(6)) {
            if (img is pw.MemoryImage) {
              // Add picture
              final xcel.Picture picture = sheet.pictures.addStream(
                currentRow,
                imgCol,
                img.bytes,
              );
              picture.width = 40;
              picture.height = 40;
              // picture.left = ... // positioning within cell
              imgCol++;
            }
          }
          currentRow++;
        }

        // D. Transactions
        if (item.transactions != null) {
          // Title
          final titleCell = sheet.getRangeByIndex(currentRow, startCol);
          titleCell.setText(item.transactions!.title);
          titleCell.cellStyle.bold = true;
          titleCell.cellStyle.fontColor = '#000000';
          currentRow++;

          // Headers
          for (int t = 0; t < item.transactions!.headers.length; t++) {
            final hCell = sheet.getRangeByIndex(currentRow, startCol + t);
            hCell.setText(item.transactions!.headers[t]);
            hCell.cellStyle.bold = true;
            hCell.cellStyle.fontSize = 9;
            hCell.cellStyle.backColor = '#EAEAEA';
          }
          currentRow++;

          // Rows
          for (var row in item.transactions!.data) {
            for (int t = 0; t < row.length; t++) {
              final dCell = sheet.getRangeByIndex(currentRow, startCol + t);
              dCell.setText(row[t]);
              dCell.cellStyle.fontSize = 9;
            }
            currentRow++;
          }
        }

        // Add a separator row or spacing
        currentRow++;
      }
    }

    // AutoFit (Optional, can be slow on large data, let's skip or limit)
    // sheet.getRangeByName('A1:H$currentRow').autoFitColumns();

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }
}
