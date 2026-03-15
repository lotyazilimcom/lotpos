import 'package:flutter/material.dart';
import '../servisler/lisans_servisi.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';
import '../yardimcilar/format_yardimcisi.dart';
import '../yardimcilar/responsive_yardimcisi.dart';

class UstBar extends StatelessWidget {
  const UstBar({
    super.key,
    required this.title,
    required this.onMenuPressed,
    this.onLicensePressed,
    this.forceShowMenuButton = false,
  });

  final String title;
  final VoidCallback onMenuPressed;
  final VoidCallback? onLicensePressed;
  final bool forceShowMenuButton;

  String _formatLosPayText(double amount) {
    final normalized = amount.isFinite ? amount : 0;
    final hasFraction =
        (normalized - normalized.truncateToDouble()).abs() > 0.0001;
    final formatted = FormatYardimcisi.sayiFormatlaOndalikli(
      normalized,
      decimalDigits: hasFraction ? 2 : 0,
    );
    return '$formatted ${tr('settings.account.lospay.unit')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide =
        MediaQuery.of(context).size.width >= 900 &&
        !ResponsiveYardimcisi.tabletMi(context);
    final showMenuButton = !isWide || forceShowMenuButton;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10), // Slimmer on mobile
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, maxWidth: 40),
                onPressed: onMenuPressed,
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          ],
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize:
                    (theme.textTheme.titleMedium?.fontSize ?? 16) +
                    (isWide ? 8 : 2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Modern & Professional Button Design
          ListenableBuilder(
            listenable: LisansServisi(),
            builder: (context, _) {
              final lisans = LisansServisi();
              final isLite = lisans.isLiteMode;
              final losPayText = _formatLosPayText(lisans.losPayBalance);
              final openLicensePage = onLicensePressed;

              Widget buildLisanslaButton() {
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        borderRadius: BorderRadius.circular(8),
                        onTap: openLicensePage,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 16 : 8,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              if (isWide) ...[
                                const SizedBox(width: 7),
                                Text(
                                  tr('common.license_now') !=
                                          'common.license_now'
                                      ? tr('common.license_now')
                                      : 'Yükselt',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Tooltip(
                      message:
                          '${tr('settings.account.lospay.label')} $losPayText',
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 11 : 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Color(0xFFB45309),
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isWide
                                  ? '${tr('settings.account.lospay.label')} $losPayText'
                                  : losPayText,
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Tooltip(
                      message: isLite ? 'LITE' : 'PRO',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        hitTestBehavior: HitTestBehavior.deferToChild,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          hitTestBehavior: HitTestBehavior.deferToChild,
                          child: GestureDetector(
                            onTap: openLicensePage,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isWide ? 11 : 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isLite
                                            ? const Color(0xFF5C6BC0)
                                            : const Color(0xFFFFA726))
                                        .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      (isLite
                                              ? const Color(0xFF5C6BC0)
                                              : const Color(0xFFFFA726))
                                          .withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLite
                                        ? Icons.shield_outlined
                                        : Icons.workspace_premium_outlined,
                                    color: isLite
                                        ? const Color(0xFF5C6BC0)
                                        : const Color(0xFFFFA726),
                                    size: 15,
                                  ),
                                  if (isWide) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      isLite ? 'LITE' : 'PRO',
                                      style: TextStyle(
                                        color: isLite
                                            ? const Color(0xFF5C6BC0)
                                            : const Color(0xFFFFA726),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isLite) buildLisanslaButton(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
