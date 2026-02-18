import 'package:flutter/material.dart';

import '../yardimcilar/ceviri/ceviri_servisi.dart';

enum DesktopVeritabaniAktarimSecimi { hicbirSeyYapma, tamAktar, birlestir }

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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                title: Text(title, style: titleStyle),
                subtitle: Text(subtitle, style: const TextStyle(height: 1.35)),
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

          const primaryColor = Color(0xFF2C3E50);
          const dialogRadius = 14.0;

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogRadius),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(dialogRadius),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('dbsync.title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(introKey),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF606368),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              secenek(
                                value:
                                    DesktopVeritabaniAktarimSecimi.hicbirSeyYapma,
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
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.end,
                        runAlignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
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
                              child: Text(tr('dbsync.not_now')),
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton(
                              onPressed: secim == null
                                  ? null
                                  : () => Navigator.of(ctx).pop(secim),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade500,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              child: Text(tr('common.continue')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
