import 'package:flutter/material.dart';

class LosposLogo extends StatelessWidget {
  const LosposLogo({
    super.key,
    this.darkBackground = false,
    this.compact = false,
    this.showFullLogo = false,
    this.iconSize = 32,
    this.fontSize = 26,
    this.logoHeight,
    this.gap = 10,
    this.text = 'Los Pos',
  });

  final bool darkBackground;
  final bool compact;
  final bool showFullLogo;
  final double iconSize;
  final double fontSize;
  final double? logoHeight;
  final double gap;
  final String text;

  static const String _appIconAsset = 'assets/branding/lospos_app_icon.png';
  static const String _darkLogoAsset = 'assets/branding/lospos_logo_dark.png';
  static const String _whiteLogoAsset = 'assets/branding/lospos_logo_white.png';

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildIcon();
    }

    if (showFullLogo) {
      return _buildFullLogo();
    }

    final textColor = darkBackground ? Colors.white : const Color(0xFF2C3E50);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIcon(),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullLogo() {
    final asset = darkBackground ? _whiteLogoAsset : _darkLogoAsset;
    final effectiveHeight = logoHeight ?? (iconSize * 1.35);

    return Image.asset(
      asset,
      height: effectiveHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            SizedBox(width: gap),
            Text(
              text,
              style: TextStyle(
                color: darkBackground ? Colors.white : const Color(0xFF2C3E50),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIcon() {
    return Image.asset(
      _appIconAsset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.inventory_2_rounded,
          size: iconSize,
          color: darkBackground ? Colors.white : const Color(0xFF2C3E50),
        );
      },
    );
  }
}
