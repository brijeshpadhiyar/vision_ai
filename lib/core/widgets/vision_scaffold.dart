import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/constants/app_constants.dart';

/// Reusable responsive scaffold with subtle ambient lighting in dark mode.
class VisionScaffold extends StatelessWidget {
  const VisionScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.constrainContentWidth = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool constrainContentWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Padding(padding: padding, child: body);

    if (constrainContentWidth) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: content,
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isDark)
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.25),
                    radius: 0.95,
                    colors: [
                      Color(0x1800E5FF),
                      Color(0x0A3B82F6),
                      AppColors.darkBackground,
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          SafeArea(child: content),
        ],
      ),
    );
  }
}
