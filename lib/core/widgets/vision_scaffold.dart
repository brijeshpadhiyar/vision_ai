import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';

/// Reusable atmospheric Liquid Glass scaffold with edge-to-edge safe areas.
class VisionScaffold extends StatelessWidget {
  const VisionScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.constrainContentWidth = true,
    this.extendBody = true,
    this.extendBodyBehindAppBar = false,
    this.useSafeAreaBottom = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool constrainContentWidth;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool useSafeAreaBottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    Widget content = Padding(padding: padding, child: body);

    if (constrainContentWidth) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final effectiveMaxWidth = screenWidth >= AppConstants.compactBreakpoint
          ? 880.0
          : AppConstants.maxContentWidth;
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: content,
        ),
      );
    }

    return Scaffold(
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: VisionColors.primaryBackground(brightness),
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? VisionColors.darkBackdropGradient
                      : VisionColors.lightBackdropGradient,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.75, -0.78),
                          radius: 0.95,
                          colors: [
                            VisionColors.accentPrimary.withValues(
                              alpha: isDark ? 0.14 : 0.10,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.85, 0.72),
                          radius: 0.95,
                          colors: [
                            VisionColors.accentSecondary.withValues(
                              alpha: isDark ? 0.12 : 0.08,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: !extendBodyBehindAppBar,
            bottom: useSafeAreaBottom && bottomNavigationBar == null,
            child: content,
          ),
        ],
      ),
    );
  }
}
