import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/widgets/glass/vision_glass_navigation.dart';

export 'package:vision_ai/core/widgets/glass/vision_glass_navigation.dart'
    show VisionNavItem;

/// Semantic entry point for the floating VISION bottom navigation bar.
class VisionBottomNavigation extends StatelessWidget {
  const VisionBottomNavigation({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final List<VisionNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return VisionGlassNavigationBar(
      items: items,
      currentIndex: currentIndex,
      onSelect: onSelect,
    );
  }
}
