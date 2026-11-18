import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/theme/vision_shadows.dart';

enum VisionGlassButtonStyle { primary, glass, tonal, danger }

/// Liquid Glass button with tactile press feedback, loading state, and glow.
class VisionGlassButton extends StatefulWidget {
  const VisionGlassButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.style = VisionGlassButtonStyle.primary,
    this.isLoading = false,
    this.expand = false,
    this.compact = false,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VisionGlassButtonStyle style;
  final bool isLoading;
  final bool expand;
  final bool compact;
  final BorderRadius? borderRadius;

  @override
  State<VisionGlassButton> createState() => _VisionGlassButtonState();
}

class _VisionGlassButtonState extends State<VisionGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.isLoading;
    final radius = widget.borderRadius ?? VisionRadii.mdBorder;
    final reducedMotion = VisionAnimations.isReducedMotion(context);

    final Color foreground = switch (widget.style) {
      VisionGlassButtonStyle.primary =>
        isDark ? VisionColors.backgroundPrimary : Colors.white,
      VisionGlassButtonStyle.tonal => VisionColors.primaryAccent(brightness),
      VisionGlassButtonStyle.danger => VisionColors.error,
      VisionGlassButtonStyle.glass => VisionColors.primaryText(brightness),
    };

    final BoxDecoration decoration = switch (widget.style) {
      VisionGlassButtonStyle.primary => BoxDecoration(
        borderRadius: radius,
        gradient: enabled
            ? VisionColors.brandGradient
            : LinearGradient(
                colors: [
                  VisionColors.accentPrimary.withValues(alpha: 0.35),
                  VisionColors.accentSecondary.withValues(alpha: 0.35),
                ],
              ),
        boxShadow: enabled
            ? VisionShadows.glassElevation(
                brightness,
                glowColor: VisionColors.accentPrimary,
                glowIntensity: 0.85,
              )
            : null,
      ),
      VisionGlassButtonStyle.tonal => VisionGlass.decoration(
        brightness,
        variant: VisionGlassVariant.accent,
        borderRadius: radius,
      ),
      VisionGlassButtonStyle.danger => BoxDecoration(
        borderRadius: radius,
        color: VisionColors.error.withValues(alpha: isDark ? 0.14 : 0.10),
        border: Border.all(color: VisionColors.error.withValues(alpha: 0.45)),
      ),
      VisionGlassButtonStyle.glass => VisionGlass.decoration(
        brightness,
        variant: VisionGlassVariant.standard,
        borderRadius: radius,
      ),
    };

    final childRow = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.compact ? 16 : 18, color: foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: theme.textTheme.labelLarge?.copyWith(
              color: enabled ? foreground : foreground.withValues(alpha: 0.55),
              fontSize: widget.compact ? 13 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedOpacity(
        duration: VisionAnimations.microFast,
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.compact ? 42 : 48),
          decoration: decoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: enabled
                  ? (val) => setState(() => _pressed = val)
                  : null,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 14 : 20,
                  vertical: widget.compact ? 9 : 12,
                ),
                child: childRow,
              ),
            ),
          ),
        ),
      ),
    );

    final sized = widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;

    if (reducedMotion) return sized;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: VisionAnimations.microFast,
      curve: VisionAnimations.standardCurve,
      child: sized,
    );
  }
}

/// Circular or squircle glass icon button with accessible touch target.
class VisionGlassIconButton extends StatefulWidget {
  const VisionGlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.size = 44,
    this.iconSize = 20,
    this.iconColor,
    this.glowColor,
    this.isActive = false,
    this.isCircle = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? glowColor;
  final bool isActive;
  final bool isCircle;

  @override
  State<VisionGlassIconButton> createState() => _VisionGlassIconButtonState();
}

class _VisionGlassIconButtonState extends State<VisionGlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = widget.glowColor ?? VisionColors.primaryAccent(brightness);
    final radius = widget.isCircle
        ? VisionRadii.pillBorder
        : VisionRadii.mdBorder;
    final reducedMotion = VisionAnimations.isReducedMotion(context);

    final button = Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        enabled: widget.onPressed != null,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: VisionGlass.decoration(
            brightness,
            variant: widget.isActive
                ? VisionGlassVariant.accent
                : VisionGlassVariant.standard,
            borderRadius: radius,
            borderColor: widget.isActive
                ? accent.withValues(alpha: 0.55)
                : null,
            glowColor: widget.isActive ? accent : null,
            glowIntensity: widget.isActive ? 0.7 : 0.0,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: widget.onPressed != null
                  ? (val) => setState(() => _pressed = val)
                  : null,
              borderRadius: radius,
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color:
                      widget.iconColor ??
                      (widget.isActive
                          ? accent
                          : VisionColors.primaryText(brightness)),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (reducedMotion) return button;

    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: VisionAnimations.microFast,
      curve: VisionAnimations.standardCurve,
      child: button,
    );
  }
}
