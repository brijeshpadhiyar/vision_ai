import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_theme.dart';

/// Centralized dark and light [ThemeData] definitions backed by [VisionTheme].
abstract final class AppTheme {
  static ThemeData get darkTheme => VisionTheme.darkTheme;
  static ThemeData get lightTheme => VisionTheme.lightTheme;
}
