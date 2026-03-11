import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextAlign textAlign;
  final TextStyle? highlightStyle;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines, // Default null for wrapping
    this.highlightStyle,
  });

  final int? maxLines;

  bool _isAllowedNumericSeparator(int codeUnit) {
    // Only allow common numeric separators between digits.
    // (Prevents highlighting across alphanumeric ids like "2A500".)
    switch (codeUnit) {
      case 0x20: // space
      case 0x09: // \t
      case 0x0A: // \n
      case 0x0D: // \r
      case 0x2E: // .
      case 0x2C: // ,
      case 0x00A0: // nbsp
      case 0x2009: // thin space
      case 0x202F: // narrow no-break space
      case 0x27: // '
      case 0x2019: // ’
      case 0x066C: // Arabic thousands separator
      case 0x066B: // Arabic decimal separator
        return true;
      default:
        return false;
    }
  }

  List<({int start, int end})> _numericHighlightRanges({
    required String originalText,
    required String queryDigits,
  }) {
    final digitIndices = <int>[];
    final digitsBuffer = StringBuffer();
    for (int i = 0; i < originalText.length; i++) {
      final int codeUnit = originalText.codeUnitAt(i);
      if (codeUnit >= 0x30 && codeUnit <= 0x39) {
        digitsBuffer.writeCharCode(codeUnit);
        digitIndices.add(i);
      }
    }

    final digitsText = digitsBuffer.toString();
    if (digitsText.isEmpty) return const [];

    final ranges = <({int start, int end})>[];
    int searchStart = 0;
    while (true) {
      final matchIndex = digitsText.indexOf(queryDigits, searchStart);
      if (matchIndex == -1) break;

      final matchEnd = matchIndex + queryDigits.length;
      bool isValid = true;
      for (int p = matchIndex; p < matchEnd - 1; p++) {
        final int a = digitIndices[p];
        final int b = digitIndices[p + 1];
        for (int i = a + 1; i < b; i++) {
          final int codeUnit = originalText.codeUnitAt(i);
          if (!_isAllowedNumericSeparator(codeUnit)) {
            isValid = false;
            break;
          }
        }
        if (!isValid) break;
      }

      if (isValid) {
        final int start = digitIndices[matchIndex];
        final int end = digitIndices[matchEnd - 1] + 1;
        ranges.add((start: start, end: end));
        // Keep behaviour consistent with the classic highlighter: do not overlap.
        searchStart = matchEnd;
      } else {
        searchStart = matchIndex + 1;
      }
    }

    if (ranges.isEmpty) return const [];

    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[];
    for (final range in ranges) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }
      final last = merged.last;
      if (range.start <= last.end) {
        final int end = range.end > last.end ? range.end : last.end;
        merged[merged.length - 1] = (start: last.start, end: end);
      } else {
        merged.add(range);
      }
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null
            ? TextOverflow.visible
            : TextOverflow.ellipsis,
      );
    }

    final baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final TextStyle resolvedHighlightStyle = highlightStyle == null
        ? baseStyle.copyWith(fontWeight: FontWeight.w900, color: Colors.black)
        : baseStyle.copyWith(fontWeight: FontWeight.w900).merge(highlightStyle);
    // Custom Turkish-aware lowercase
    String turkishToLower(String input) {
      return input
          .replaceAll('İ', 'i')
          .replaceAll('I', 'ı')
          .toLowerCase()
          .replaceAll(
            'i̇',
            'i',
          ); // Normalizing potential combining dot artifacts
    }

    final lowerText = turkishToLower(text);
    final lowerQuery = turkishToLower(query);

    // If there is no direct match but the user searched only with digits,
    // try to highlight formatted numbers (e.g., "2.494" for "2494").
    final String trimmedQuery = query.trim();
    final String queryDigits = trimmedQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final bool queryLooksNumeric =
        queryDigits.isNotEmpty &&
        RegExp(
          r"^[0-9\s\.,\u00A0\u2009\u202F'’\u066B\u066C\-]+$",
        ).hasMatch(trimmedQuery);

    if (!lowerText.contains(lowerQuery) && queryLooksNumeric) {
      final ranges = _numericHighlightRanges(
        originalText: text,
        queryDigits: queryDigits,
      );
      if (ranges.isNotEmpty) {
        final List<TextSpan> spans = [];
        int cursor = 0;
        for (final range in ranges) {
          if (range.start > cursor) {
            spans.add(TextSpan(text: text.substring(cursor, range.start)));
          }
          spans.add(
            TextSpan(
              text: text.substring(range.start, range.end),
              style: resolvedHighlightStyle,
            ),
          );
          cursor = range.end;
        }
        if (cursor < text.length) {
          spans.add(TextSpan(text: text.substring(cursor)));
        }
        return RichText(
          text: TextSpan(style: baseStyle, children: spans),
          overflow: maxLines == null
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          maxLines: maxLines,
          textAlign: textAlign,
        );
      }
    }

    // Basit bir split yerine regex veya index mantığı daha güvenli olabilir
    // Ancak burada basitçe index takibi yapacağız
    List<TextSpan> spans = [];
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: resolvedHighlightStyle,
        ),
      );
      start = index + lowerQuery.length;
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
      maxLines: maxLines,
      textAlign: textAlign,
    );
  }
}
