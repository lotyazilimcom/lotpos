import 'package:flutter/material.dart';

import '../yardimcilar/ceviri/ceviri_servisi.dart';

enum DesktopVeritabaniAktarimSecimi {
  hicbirSeyYapma,
  tamAktar,
  birlestir,
}

Future<DesktopVeritabaniAktarimSecimi?> veritabaniAktarimSecimDialogGoster({
  required BuildContext context,
  required bool localToCloud,
  bool barrierDismissible = false,
}) async {
  DesktopVeritabaniAktarimSecimi? secim;

  return showDialog<DesktopVeritabaniAktarimSecimi>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final introKey = localToCloud
              ? 'dbsync.desktop.local_to_cloud.intro'
              : 'dbsync.desktop.cloud_to_local.intro';

          Widget secenek({
            required DesktopVeritabaniAktarimSecimi value,
            required String title,
            required String subtitle,
            bool destructive = false,
          }) {
            final selected = secim == value;
            final scheme = Theme.of(ctx).colorScheme;

            Color borderColor = scheme.outline.withValues(alpha: 0.25);
            Color bgColor = Colors.transparent;
            if (selected) {
              borderColor = scheme.primary.withValues(alpha: 0.35);
              bgColor = scheme.primary.withValues(alpha: 0.06);
            }

            final titleStyle = TextStyle(
              fontWeight: FontWeight.w800,
              color: destructive ? const Color(0xFFEA4335) : null,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: CheckboxListTile(
                value: selected,
                onChanged: (_) => setState(() => secim = value),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                title: Text(title, style: titleStyle),
                subtitle: Text(
                  subtitle,
                  style: const TextStyle(height: 1.35),
                ),
              ),
            );
          }

          final noneDescKey = localToCloud
              ? 'dbsync.option.none.desc.local_to_cloud'
              : 'dbsync.option.none.desc.cloud_to_local';
          final fullDescKey = localToCloud
              ? 'dbsync.option.full.desc.local_to_cloud'
              : 'dbsync.option.full.desc.cloud_to_local';
          final mergeDescKey = localToCloud
              ? 'dbsync.option.merge.desc.local_to_cloud'
              : 'dbsync.option.merge.desc.cloud_to_local';

          return AlertDialog(
            title: Text(tr('dbsync.title')),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(introKey),
                      style: const TextStyle(height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    secenek(
                      value: DesktopVeritabaniAktarimSecimi.hicbirSeyYapma,
                      title: tr('dbsync.option.none.title'),
                      subtitle: tr(noneDescKey),
                    ),
                    secenek(
                      value: DesktopVeritabaniAktarimSecimi.tamAktar,
                      title: tr('dbsync.full'),
                      subtitle: tr(fullDescKey),
                      destructive: true,
                    ),
                    secenek(
                      value: DesktopVeritabaniAktarimSecimi.birlestir,
                      title: tr('dbsync.merge'),
                      subtitle: tr(mergeDescKey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('dbsync.not_now')),
              ),
              FilledButton(
                onPressed: secim == null ? null : () => Navigator.of(ctx).pop(secim),
                child: Text(tr('common.continue')),
              ),
            ],
          );
        },
      );
    },
  );
}
