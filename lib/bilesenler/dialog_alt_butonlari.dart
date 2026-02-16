import 'package:flutter/material.dart';

enum DialogOnayStili { kirmizi, turuncu, gri }

class DialogAltButonlari extends StatelessWidget {
  final String iptalMetni;
  final String onayMetni;
  final VoidCallback? onIptal;
  final VoidCallback? onOnay;
  final String? iptalKisayol;
  final String? onayKisayol;
  final bool yukleniyor;
  final DialogOnayStili onayStili;

  const DialogAltButonlari({
    super.key,
    required this.iptalMetni,
    required this.onayMetni,
    this.onIptal,
    this.onOnay,
    this.iptalKisayol,
    this.onayKisayol,
    this.yukleniyor = false,
    this.onayStili = DialogOnayStili.kirmizi,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 420;
        final double maxRowWidth =
            (constraints.maxWidth > 320 ? 320 : constraints.maxWidth)
                .toDouble();
        const double gap = 12;
        final double buttonWidth = (maxRowWidth - gap) / 2;

        Color confirmBg;
        Color confirmFg;
        switch (onayStili) {
          case DialogOnayStili.turuncu:
            confirmBg = scheme.secondary;
            confirmFg = scheme.onSecondary;
            break;
          case DialogOnayStili.gri:
            confirmBg = scheme.outline;
            confirmFg = scheme.onSurface;
            break;
          case DialogOnayStili.kirmizi:
            confirmBg = scheme.tertiary;
            confirmFg = scheme.onTertiary;
            break;
        }

        final cancelButton = OutlinedButton(
          onPressed: onIptal,
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.primary,
            side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: compact
              ? Text(iptalMetni, maxLines: 1, overflow: TextOverflow.ellipsis)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      iptalMetni,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (iptalKisayol != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        iptalKisayol!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.outline.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
        );

        final confirmButton = ElevatedButton(
          onPressed: yukleniyor ? null : onOnay,
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmBg,
            foregroundColor: confirmFg,
            disabledBackgroundColor: scheme.outline.withValues(alpha: 0.25),
            disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.65),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          child: yukleniyor
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: confirmFg,
                  ),
                )
              : compact
                  ? Text(onayMetni, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          onayMetni,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (onayKisayol != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            onayKisayol!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: confirmFg.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
        );

        if (compact) {
          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: maxRowWidth,
              child: Row(
                children: [
                  SizedBox(width: buttonWidth, child: cancelButton),
                  const SizedBox(width: gap),
                  SizedBox(width: buttonWidth, child: confirmButton),
                ],
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            cancelButton,
            const SizedBox(width: 12),
            confirmButton,
          ],
        );
      },
    );
  }
}
