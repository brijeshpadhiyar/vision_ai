import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_dark_theme.dart';
import 'package:vision_ai/core/theme/vision_light_theme.dart';

/// Unified entry point for VISION AI Midnight Violet (dark) & Pearl Lavender (light) themes.
abstract final class VisionTheme {
  static ThemeData get darkTheme => VisionDarkTheme.build();

  static ThemeData get lightTheme => VisionLightTheme.build();
}
