import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../temalar/app_theme.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

class DateRangeDefaults {
  const DateRangeDefaults._({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static DateRangeDefaults currentMonth([DateTime? reference]) {
    final DateTime now = reference == null
        ? DateTime.now()
        : DateTime(reference.year, reference.month, reference.day);

    return DateRangeDefaults._(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  static bool matchesCurrentMonth(
    DateTime? start,
    DateTime? end, [
    DateTime? reference,
  ]) {
    if (start == null || end == null) return false;

    final DateRangeDefaults current = currentMonth(reference);
    final DateTime normalizedStart = DateTime(
      start.year,
      start.month,
      start.day,
    );
    final DateTime normalizedEnd = DateTime(end.year, end.month, end.day);

    return normalizedStart == current.start && normalizedEnd == current.end;
  }

  static bool isCustomSelection(
    DateTime? start,
    DateTime? end, [
    DateTime? reference,
  ]) {
    return (start != null || end != null) &&
        !matchesCurrentMonth(start, end, reference);
  }

  void writeToControllers({
    TextEditingController? startController,
    TextEditingController? endController,
    String pattern = 'dd.MM.yyyy',
  }) {
    final DateFormat formatter = DateFormat(pattern);
    startController?.text = formatter.format(start);
    endController?.text = formatter.format(end);
  }
}

class ResponsiveFilterItem {
  const ResponsiveFilterItem({
    required this.child,
    this.desktopWidth = 200,
    this.tabletWidth = 190,
    this.mobileWidth = 180,
    this.minWidth = 160,
  });

  final Widget child;
  final double desktopWidth;
  final double tabletWidth;
  final double mobileWidth;
  final double minWidth;
}

class ResponsiveFilterRow extends StatelessWidget {
  const ResponsiveFilterRow({
    super.key,
    required this.items,
    this.spacing = 20,
    this.runSpacing = 16,
    this.prioritizeFirstItem = true,
    this.tabletBreakpoint = 1400,
  });

  final List<ResponsiveFilterItem> items;
  final double spacing;
  final double runSpacing;
  final bool prioritizeFirstItem;
  final double tabletBreakpoint;

  List<double>? _resolveWidths(double maxWidth, bool isTablet) {
    if (items.isEmpty || maxWidth <= 0) return null;

    final List<double> baseWidths = items
        .map((item) => isTablet ? item.tabletWidth : item.desktopWidth)
        .toList();
    final List<double> minWidths = items.map((item) => item.minWidth).toList();

    final double spacingTotal = spacing * math.max(0, items.length - 1);
    final double minTotal =
        minWidths.fold<double>(0, (sum, width) => sum + width) + spacingTotal;
    if (minTotal > maxWidth) {
      return null;
    }

    final double usableWidth = maxWidth - spacingTotal;
    final double baseWidthSum = baseWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    final double baseTotal = baseWidthSum + spacingTotal;

    if (baseTotal <= maxWidth) {
      final double extraPerItem = (usableWidth - baseWidthSum) / items.length;
      return baseWidths.map((width) => width + extraPerItem).toList();
    }

    final double minWidthSum = minWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );

    if (!prioritizeFirstItem || items.length == 1) {
      final double ratio =
          ((usableWidth - minWidthSum) / (baseWidthSum - minWidthSum)).clamp(
            0.0,
            1.0,
          );

      return List<double>.generate(items.length, (index) {
        return minWidths[index] +
            (baseWidths[index] - minWidths[index]) * ratio;
      });
    }

    final List<double> widths = List<double>.from(minWidths);
    double remaining = usableWidth - minWidthSum;
    if (remaining <= 0) return widths;

    final double primaryCapacity = math.max(0, baseWidths[0] - minWidths[0]);
    final double primaryAdd = math.min(remaining, primaryCapacity);
    widths[0] += primaryAdd;
    remaining -= primaryAdd;
    if (remaining <= 0) return widths;

    double othersCapacity = 0;
    for (int i = 1; i < widths.length; i++) {
      othersCapacity += math.max(0, baseWidths[i] - minWidths[i]);
    }
    if (othersCapacity <= 0) return widths;

    final double ratio = (remaining / othersCapacity).clamp(0.0, 1.0);
    for (int i = 1; i < widths.length; i++) {
      widths[i] += math.max(0, baseWidths[i] - minWidths[i]) * ratio;
    }

    return widths;
  }

  Widget _buildRow(List<double> widths) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(items.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == items.length - 1 ? 0 : spacing,
          ),
          child: SizedBox(width: widths[index], child: items[index].child),
        );
      }),
    );
  }

  Widget _buildWrap(double maxWidth, bool isTablet) {
    final List<double> fallbackWidths = items
        .map((item) => isTablet ? item.tabletWidth : item.desktopWidth)
        .toList();

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: List<Widget>.generate(items.length, (index) {
        return SizedBox(
          width: math.min(maxWidth, fallbackWidths[index]),
          child: items[index].child,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth < tabletBreakpoint;
        final List<double>? widths = _resolveWidths(
          constraints.maxWidth,
          isTablet,
        );

        if (widths == null) {
          return _buildWrap(constraints.maxWidth, isTablet);
        }

        return _buildRow(widths);
      },
    );
  }
}

class RaporStiliTarihAraligiFiltresi extends StatelessWidget {
  const RaporStiliTarihAraligiFiltresi({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onPresetSelected,
    required this.onCustomTap,
    this.width,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime? start, DateTime? end) onPresetSelected;
  final VoidCallback onCustomTap;
  final double? width;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _startOfWeek(DateTime now) {
    final DateTime today = _dateOnly(now);
    final int diff = today.weekday - DateTime.monday;
    return today.subtract(Duration(days: diff));
  }

  static DateTime _endOfWeek(DateTime now) =>
      _startOfWeek(now).add(const Duration(days: 6));

  static DateTime _startOfMonth(DateTime now) =>
      DateTime(now.year, now.month, 1);

  static DateTime _endOfMonth(DateTime now) =>
      DateTime(now.year, now.month + 1, 0);

  String _selectedPresetKey() {
    if (startDate == null && endDate == null) return 'all';
    if (startDate == null || endDate == null) return 'custom';

    final DateTime now = DateTime.now();
    final DateTime normalizedStart = _dateOnly(startDate!);
    final DateTime normalizedEnd = _dateOnly(endDate!);
    final DateTime today = _dateOnly(now);

    if (normalizedStart == today && normalizedEnd == today) {
      return 'today';
    }
    if (normalizedStart == _startOfWeek(now) &&
        normalizedEnd == _endOfWeek(now)) {
      return 'this_week';
    }
    if (normalizedStart == _startOfMonth(now) &&
        normalizedEnd == _endOfMonth(now)) {
      return 'this_month';
    }
    return 'custom';
  }

  String _summaryText() {
    if (startDate == null && endDate == null) return '';
    final DateFormat formatter = DateFormat('dd.MM.yyyy');
    final String start = startDate != null ? formatter.format(startDate!) : '';
    final String end = endDate != null ? formatter.format(endDate!) : '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  void _applyPreset(String key) {
    final DateTime now = DateTime.now();
    switch (key) {
      case 'all':
        onPresetSelected(null, null);
        return;
      case 'today':
        final DateTime today = _dateOnly(now);
        onPresetSelected(today, today);
        return;
      case 'this_week':
        onPresetSelected(_startOfWeek(now), _endOfWeek(now));
        return;
      case 'this_month':
        onPresetSelected(_startOfMonth(now), _endOfMonth(now));
        return;
      case 'custom':
        onCustomTap();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String selectedPresetKey = _selectedPresetKey();
    final String summaryText = _summaryText();
    final List<MapEntry<String, String>> items = <MapEntry<String, String>>[
      MapEntry('all', tr('common.all')),
      MapEntry('today', tr('reports.presets.today')),
      MapEntry('this_week', tr('reports.presets.this_week')),
      MapEntry('this_month', tr('reports.presets.this_month')),
      MapEntry('custom', tr('reports.presets.custom')),
    ];

    Widget buildPresetChip(MapEntry<String, String> item) {
      final bool selected = selectedPresetKey == item.key;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        onTap: () => _applyPreset(item.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppPalette.slate : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppPalette.slate
                  : AppPalette.grey.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            item.value,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppPalette.slate,
            ),
          ),
        ),
      );
    }

    Widget buildSummary(double maxWidth) {
      if (selectedPresetKey != 'custom' || summaryText.isEmpty) {
        return const SizedBox.shrink();
      }

      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.max(120, maxWidth * 0.35)),
        child: Text(
          summaryText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppPalette.grey),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool useStackedLayout = constraints.maxWidth < 360;

          Widget buildPresetWrap(double maxWidth) {
            return Wrap(
              spacing: 5,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...items.map(buildPresetChip),
                if (selectedPresetKey == 'custom' && summaryText.isNotEmpty)
                  buildSummary(maxWidth),
              ],
            );
          }

          return Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: useStackedLayout
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('common.date_range'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      buildPresetWrap(constraints.maxWidth),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          tr('common.date_range'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: buildPresetWrap(constraints.maxWidth)),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
