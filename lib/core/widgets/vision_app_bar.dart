import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/widgets/glass/vision_glass_navigation.dart';

/// Reusable Liquid Glass application bar with VISION typography and actions.
class VisionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VisionAppBar({
    required this.title,
    super.key,
    this.subtitle,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.enableBlur = true,
    this.titleWidget,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool enableBlur;
  final Widget? titleWidget;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    return VisionGlassAppBar(
      title: title,
      subtitle: subtitle,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      enableBlur: enableBlur,
      titleWidget: titleWidget,
    );
  }
}
