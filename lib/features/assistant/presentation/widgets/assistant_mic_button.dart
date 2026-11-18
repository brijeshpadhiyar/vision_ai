import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_button.dart';

/// Quick voice & wake-word interaction bar for the VISION Home dashboard.
class AssistantMicButton extends StatelessWidget {
  const AssistantMicButton({
    required this.onPressed,
    super.key,
    this.isListening = false,
    this.isSpeaking = false,
    this.isWakeActive = false,
    this.statusLabel,
    this.onWakeWordTap,
  });

  final VoidCallback onPressed;
  final bool isListening;
  final bool isSpeaking;
  final bool isWakeActive;
  final String? statusLabel;
  final VoidCallback? onWakeWordTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final primaryAccent = isListening
        ? VisionColors.success
        : isSpeaking
        ? VisionColors.warning
        : VisionColors.accentPrimary;

    final defaultLabel = isListening
        ? 'Listening... Tap to Open Assistant'
        : isSpeaking
        ? 'Speaking Reply • Tap to Interrupt'
        : 'Tap to Speak with VISION';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: VisionGlass.decoration(
              brightness,
              variant: VisionGlassVariant.elevated,
              borderRadius: VisionRadii.pillBorder,
              glowColor: primaryAccent,
              glowIntensity: isListening ? 0.8 : 0.35,
              showShadow: true,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: statusLabel ?? defaultLabel,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPressed,
                      borderRadius: VisionRadii.pillBorder,
                      child: AnimatedContainer(
                        duration: VisionAnimations.resolveDuration(
                          context,
                          VisionAnimations.micro,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: VisionRadii.pillBorder,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryAccent,
                              VisionColors.accentSecondary,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isListening
                                  ? Icons.graphic_eq_rounded
                                  : isSpeaking
                                  ? Icons.volume_off_rounded
                                  : Icons.mic_none_rounded,
                              size: 22,
                              color: VisionColors.backgroundPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isListening
                                  ? 'Listening'
                                  : isSpeaking
                                  ? 'Interrupt'
                                  : 'Ask VISION',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: VisionColors.backgroundPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (onWakeWordTap != null) ...[
                  const SizedBox(width: 10),
                  VisionGlassIconButton(
                    icon: Icons.hearing_rounded,
                    tooltip: 'Listen for "Hey VISION" wake word',
                    isActive: isWakeActive,
                    glowColor: VisionColors.success,
                    onPressed: onWakeWordTap,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          statusLabel ?? defaultLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isListening
                ? VisionColors.success
                : VisionColors.secondaryText(brightness),
          ),
        ),
      ],
    );
  }
}
