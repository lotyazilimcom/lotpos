import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ResponsiveYardimcisi {
  static bool tabletMi(BuildContext context) {
    if (kIsWeb) return false;

    final platform = defaultTargetPlatform;
    final bool isMobilePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (!isMobilePlatform) return false;

    // Yaygın yaklaşım: shortestSide >= 600 => tablet
    return MediaQuery.sizeOf(context).shortestSide >= 600;
  }
}

