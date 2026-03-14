import 'package:flutter/material.dart';

class KlavyeKisayolRozeti extends StatelessWidget {
  const KlavyeKisayolRozeti._({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
    this.compact = false,
  });

  factory KlavyeKisayolRozeti.filled({
    Key? key,
    required String label,
    Color textColor = Colors.white,
    bool compact = false,
  }) {
    return KlavyeKisayolRozeti._(
      key: key,
      label: label,
      textColor: textColor,
      backgroundColor: Colors.white.withValues(alpha: 0.18),
      compact: compact,
    );
  }

  factory KlavyeKisayolRozeti.neutral({
    Key? key,
    required String label,
    Color textColor = const Color(0xFF6B7280),
    Color backgroundColor = const Color(0xFFF1F3F4),
    Color borderColor = const Color(0xFFE0E3E7),
    bool compact = false,
  }) {
    return KlavyeKisayolRozeti._(
      key: key,
      label: label,
      textColor: textColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      compact: compact,
    );
  }

  factory KlavyeKisayolRozeti.tinted({
    Key? key,
    required String label,
    required Color color,
    bool compact = false,
  }) {
    return KlavyeKisayolRozeti._(
      key: key,
      label: label,
      textColor: color,
      backgroundColor: color.withValues(alpha: 0.14),
      compact: compact,
    );
  }

  factory KlavyeKisayolRozeti.menu({
    Key? key,
    required String label,
    bool compact = false,
    bool enabled = true,
  }) {
    return KlavyeKisayolRozeti._(
      key: key,
      label: label,
      textColor: enabled ? const Color(0xFF7A7F87) : const Color(0xFFB8BDC5),
      backgroundColor: enabled
          ? const Color(0xFFF3F4F6)
          : const Color(0xFFF7F7F8),
      borderColor: enabled ? const Color(0xFFE5E7EB) : const Color(0xFFEAEAEC),
      compact: compact,
    );
  }

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color? borderColor;
  final bool compact;

  String get _displayLabel => label.replaceAll(RegExp(r'[\[\]]'), '').trim();

  @override
  Widget build(BuildContext context) {
    final verticalPadding = compact ? 1.0 : 2.0;
    final horizontalPadding = compact ? 4.0 : 6.0;
    final fontSize = compact ? 10.0 : 11.0;
    final radius = compact ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        _displayLabel,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: 1.05,
        ),
      ),
    );
  }
}
