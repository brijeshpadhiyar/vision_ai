import 'package:material_ui/material_ui.dart';

/// Centralized corner radius tokens for VISION AI components.
abstract final class VisionRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius xsBorder = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smBorder = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(pill),
  );
}
