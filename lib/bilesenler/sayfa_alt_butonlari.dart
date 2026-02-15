import 'package:flutter/material.dart';

import 'dialog_alt_butonlari.dart';

export 'dialog_alt_butonlari.dart' show DialogOnayStili;

class SayfaAltBar extends StatelessWidget {
  final Widget child;
  final bool compact;
  final double maxWidth;

  const SayfaAltBar({
    super.key,
    required this.child,
    required this.compact,
    this.maxWidth = 850,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;

    return Container(
      padding:
          compact ? const EdgeInsets.fromLTRB(16, 12, 16, 12) : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SayfaAltButonlari extends StatelessWidget {
  final String solMetin;
  final IconData? solIcon;
  final VoidCallback? onSol;
  final String? solKisayol;

  final String sagMetin;
  final IconData? sagIcon;
  final VoidCallback? onSag;
  final String? sagKisayol;
  final bool yukleniyor;
  final DialogOnayStili sagStil;

  const SayfaAltButonlari({
    super.key,
    required this.solMetin,
    required this.sagMetin,
    this.solIcon,
    this.onSol,
    this.solKisayol,
    this.sagIcon,
    this.onSag,
    this.sagKisayol,
    this.yukleniyor = false,
    this.sagStil = DialogOnayStili.kirmizi,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 520;
        final double maxRowWidth =
            (constraints.maxWidth > 320 ? 320 : constraints.maxWidth).toDouble();
        const double gap = 12;
        final double buttonWidth = (maxRowWidth - gap) / 2;

        Color confirmBg;
        Color confirmFg;
        switch (sagStil) {
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

        final leftButton = OutlinedButton(
          onPressed: onSol,
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.primary,
            side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (solIcon != null) ...[
                Icon(solIcon, size: compact ? 16 : 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  solMetin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!compact && solKisayol != null) ...[
                const SizedBox(width: 6),
                Text(
                  solKisayol!,
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

        final rightButton = ElevatedButton(
          onPressed: yukleniyor ? null : onSag,
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
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sagIcon != null) ...[
                      Icon(sagIcon, size: compact ? 16 : 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        sagMetin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!compact && sagKisayol != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        sagKisayol!,
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
                  SizedBox(width: buttonWidth, child: leftButton),
                  const SizedBox(width: gap),
                  SizedBox(width: buttonWidth, child: rightButton),
                ],
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            leftButton,
            const SizedBox(width: 12),
            rightButton,
          ],
        );
      },
    );
  }
}
