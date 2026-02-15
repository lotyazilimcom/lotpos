import 'package:flutter/material.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

class OnayDialog extends StatelessWidget {
  final String baslik;
  final String mesaj;
  final String? onayButonMetni;
  final String? iptalButonMetni;
  final VoidCallback onOnay;
  final bool isDestructive;

  const OnayDialog({
    super.key,
    required this.baslik,
    required this.mesaj,
    required this.onOnay,
    this.onayButonMetni,
    this.iptalButonMetni,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final String onayMetni = onayButonMetni ?? tr('common.yes');
    final String iptalMetni = iptalButonMetni ?? tr('common.cancel');

    const dialogRadius = 14.0;
    const primaryColor = Color(0xFF2C3E50);
    const destructiveColor = Color(0xFFEA4335);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: 450,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? destructiveColor.withValues(alpha: 0.1)
                        : primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDestructive
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded,
                    color: isDestructive ? destructiveColor : primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    baslik,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202124),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              mesaj,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF606368),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      foregroundColor: primaryColor,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(iptalMetni),
                  ),
                ),
                const SizedBox(width: 12),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onOnay();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destructiveColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(onayMetni),
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
