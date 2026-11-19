import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Consistent semantic text field inheriting the centralized Material 3
/// [InputDecorationTheme] from [VisionDarkTheme] / [VisionLightTheme].
class VisionTextField extends StatelessWidget {
  const VisionTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 19, color: colors.textSecondary)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
