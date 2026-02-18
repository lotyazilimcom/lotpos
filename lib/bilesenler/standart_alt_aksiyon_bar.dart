import 'package:flutter/material.dart';

class StandartAltAksiyonBar extends StatelessWidget {
  const StandartAltAksiyonBar({
    super.key,
    required this.isCompact,
    required this.secondaryText,
    required this.onSecondaryPressed,
    required this.primaryText,
    required this.onPrimaryPressed,
    this.secondaryIcon = Icons.close_rounded,
    this.secondaryHintText,
    this.primaryLoading = false,
    this.maxWidthCompact = 760,
    this.maxWidthWide = 850,
    this.primaryColor = const Color(0xFFEA4335),
    this.textColor = const Color(0xFF2C3E50),
  });

  final bool isCompact;

  final String secondaryText;
  final VoidCallback? onSecondaryPressed;
  final IconData secondaryIcon;
  final String? secondaryHintText;

  final String primaryText;
  final VoidCallback? onPrimaryPressed;
  final bool primaryLoading;

  final double maxWidthCompact;
  final double maxWidthWide;

  final Color primaryColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: isCompact
          ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact ? maxWidthCompact : maxWidthWide,
          ),
          child: _buildActionButtons(),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (isCompact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final double maxRowWidth =
              constraints.maxWidth > 320 ? 320 : constraints.maxWidth;
          const double gap = 10;
          final double buttonWidth = (maxRowWidth - gap) / 2;

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: maxRowWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: OutlinedButton.icon(
                      onPressed: onSecondaryPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(secondaryIcon, size: 15),
                      label: Text(
                        secondaryText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: buttonWidth,
                    child: ElevatedButton(
                      onPressed: primaryLoading ? null : onPrimaryPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: primaryLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              primaryText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onSecondaryPressed,
          style: TextButton.styleFrom(
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          ),
          child: Row(
            children: [
              Icon(secondaryIcon, size: 20),
              const SizedBox(width: 8),
              Text(
                secondaryText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (secondaryHintText != null) ...[
                const SizedBox(width: 6),
                Text(
                  secondaryHintText!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: primaryLoading ? null : onPrimaryPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: primaryLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  primaryText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ],
    );
  }
}
