import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_typography.dart';

/// Typography scale aliases backed by [VisionTypography].
abstract final class AppTypography {
  static TextTheme buildTextTheme({
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final brightness = primaryTextColor.computeLuminance() > 0.5
        ? Brightness.dark
        : Brightness.light;
    return VisionTypography.buildTextTheme(brightness);
  }
}
