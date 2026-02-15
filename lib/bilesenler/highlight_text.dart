import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextAlign textAlign;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines, // Default null for wrapping
  });

  final int? maxLines;

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
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
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
