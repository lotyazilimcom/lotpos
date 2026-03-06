import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';
import '../servisler/lite_kisitlari.dart';

class TarihAraligiSeciciDialog extends StatefulWidget {
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const TarihAraligiSeciciDialog({
    super.key,
    this.firstDate,
    this.lastDate,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<TarihAraligiSeciciDialog> createState() =>
      _TarihAraligiSeciciDialogState();
}

class _TarihAraligiSeciciDialogState extends State<TarihAraligiSeciciDialog> {
  DateTime? _start;
  DateTime? _end;
  bool _focusingStart = true;

  // Ana Tema Rengi
  static const Color primaryRed = Color(0xFFEA4335);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF202124);

  @override
  void initState() {
    super.initState();
    _start = widget.initialStartDate;
    _end = widget.initialEndDate;
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      if (_focusingStart) {
        _start = date;
        _focusingStart = false; // Bitiş tarihine odaklan
      } else {
        _end = date;
      }
    });
  }

  DateTime _dateOnlyLocal(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> _handleApply() async {
    if (LiteKisitlari.isLiteMode) {
      final now = DateTime.now();
      final today = _dateOnlyLocal(now);
      final allowedStart =
          today.subtract(Duration(days: LiteKisitlari.raporGun - 1));

      final start = _start != null ? _dateOnlyLocal(_start!) : null;
      final end = _end != null ? _dateOnlyLocal(_end!) : null;

      final violates = (start != null && start.isBefore(allowedStart)) ||
          (end != null && end.isBefore(allowedStart));

      if (violates) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('common.lite_version')),
            content: Text(
              tr(
                'common.lite_report_limit',
                args: {'days': LiteKisitlari.raporGun.toString()},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('common.close')),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop([_start, _end]);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: surfaceWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 450,
        decoration: BoxDecoration(
          color: surfaceWhite,
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
                  tr('common.date_range_select'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 22,
                    color: Color(0xFF3C4043),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Giriş Alanları
            Row(
              children: [
                Expanded(
                  child: _buildInputBox(
                    label: tr('common.start_date'),
                    date: _start,
                    isActive: _focusingStart,
                    onTap: () => setState(() => _focusingStart = true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputBox(
                    label: tr('common.end_date'),
                    date: _end,
                    isActive: !_focusingStart,
                    onTap: () => setState(() => _focusingStart = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Takvim
            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: Theme(
                data: ThemeData(
                  useMaterial3: true,
                  colorScheme: const ColorScheme.light(
                    primary: primaryRed,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: textDark,
                    secondary: primaryRed,
                  ),
                  datePickerTheme: DatePickerThemeData(
                    dayShape: WidgetStateProperty.all(const CircleBorder()),
                    dayBackgroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return primaryRed;
                      }
                      return null;
                    }),
                    dayForegroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return textDark;
                    }),
                    todayBorder: const BorderSide(color: primaryRed, width: 1),
                    todayForegroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return primaryRed;
                    }),
                    todayBackgroundColor: WidgetStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return primaryRed;
                      }
                      return Colors.transparent;
                    }),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CalendarDatePicker(
                    initialDate:
                        (_focusingStart ? _start : _end) ?? DateTime.now(),
                    firstDate: widget.firstDate ?? DateTime(2000),
                    lastDate: widget.lastDate ?? DateTime(2050),
                    onDateChanged: _onDateChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Alt Butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _start = null;
                      _end = null;
                      _focusingStart = true;
                    });
                  },
                  child: Text(
                    tr('common.clean'),
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        tr('common.cancel'),
                        style: const TextStyle(
                          color: Color(0xFF5F6368),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _handleApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
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
                        tr('common.apply'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required String label,
    required DateTime? date,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? primaryRed.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? primaryRed : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? primaryRed : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: isActive ? primaryRed : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? DateFormat('dd.MM.yyyy').format(date)
                      : '--.--.----',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: date != null ? textDark : Colors.grey.shade400,
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
