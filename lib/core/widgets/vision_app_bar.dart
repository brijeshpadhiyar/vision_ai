import 'package:material_ui/material_ui.dart';

/// Reusable application bar with clean VISION typography and optional actions.
class VisionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VisionAppBar({
    required this.title,
    super.key,
    this.subtitle,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      leading: leading,
      centerTitle: centerTitle,
      actions: actions,
      title: subtitle == null
          ? Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
    );
  }
}
