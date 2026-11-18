import 'package:material_ui/material_ui.dart';

/// Consistent spacing and layout scale for VISION AI.
abstract final class VisionSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 44.0;

  /// Horizontal screen gutter optimized for OPPO Reno 16 and compact phones.
  static const double screenHorizontal = 18.0;

  /// Vertical clearance reserved above the floating glass navigation bar.
  static const double navBarClearance = 104.0;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: sm,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(sm);

  /// Minimum interactive touch target size per WCAG / Android Material guidelines.
  static const double minTouchTarget = 48.0;
}
