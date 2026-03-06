import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

class TekTarihSeciciDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? title;

  const TekTarihSeciciDialog({
    super.key,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
    this.title,
  });

  @override
  State<TekTarihSeciciDialog> createState() => _TekTarihSeciciDialogState();
}

class _TekTarihSeciciDialogState extends State<TekTarihSeciciDialog> {
  late DateTime _selectedDate;
  DateTime? _lastTapDate;
  int _lastTapTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  void _onDateChanged(DateTime date) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isDoubleClick =
        _lastTapDate != null &&
        _lastTapDate!.isAtSameMomentAs(date) &&
        (now - _lastTapTimestamp) < 300;

    setState(() {
      _selectedDate = date;
    });

    if (isDoubleClick) {
      Navigator.of(context).pop(_selectedDate);
    }

    _lastTapDate = date;
    _lastTapTimestamp = now;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title ?? tr('common.date_select'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202124),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('common.esc'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 22,
                          color: Color(0xFF3C4043),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Selected Date Input (Look)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEA4335).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEA4335), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('common.date'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEA4335),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Color(0xFFEA4335),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd.MM.yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Calendar
            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: Theme(
                data: ThemeData(
                  useMaterial3: true,
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFEA4335),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF202124),
                    secondary: Color(0xFFEA4335),
                  ),
                  datePickerTheme: DatePickerThemeData(
                    dayShape: WidgetStateProperty.all(const CircleBorder()),
                    dayBackgroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFEA4335);
                      }
                      return null;
                    }),
                    dayForegroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return const Color(0xFF202124);
                    }),
                    todayBorder: const BorderSide(
                      color: Color(0xFFEA4335),
                      width: 1,
                    ),
                    todayForegroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return const Color(0xFFEA4335);
                    }),
                    todayBackgroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFEA4335);
                      }
                      return Colors.transparent;
                    }),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: widget.firstDate ?? DateTime(2000),
                    lastDate: widget.lastDate ?? DateTime(2050),
                    onDateChanged: _onDateChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2C3E50),
                  ),
                  child: Text(
                    tr('common.cancel'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_selectedDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA4335),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    tr('common.select'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
