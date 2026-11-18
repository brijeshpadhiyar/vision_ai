import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';

/// Interactive voice control button for the VISION Assistant home screen.
class AssistantMicButton extends StatelessWidget {
  const AssistantMicButton({
    required this.onPressed,
    super.key,
    this.isListening = false,
    this.isSpeaking = false,
    this.statusLabel,
    this.onWakeWordTap,
  });

  final VoidCallback onPressed;
  final bool isListening;
  final bool isSpeaking;
  final String? statusLabel;
  final VoidCallback? onWakeWordTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryAccent = isListening
        ? AppColors.success
        : isSpeaking
        ? AppColors.warning
        : AppColors.cyanAccent;

    final secondaryAccent = isListening
        ? AppColors.cyanAccent
        : AppColors.electricBlue;

    final defaultLabel = isListening
        ? 'Listening... Tap to Stop'
        : isSpeaking
        ? 'Speaking Reply • Tap to Stop'
        : 'Tap to Speak with VISION';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: statusLabel ?? defaultLabel,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryAccent, secondaryAccent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryAccent.withValues(alpha: 0.36),
                          blurRadius: isListening ? 28 : 20,
                          spreadRadius: isListening ? 3 : 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isListening
                            ? Icons.stop_rounded
                            : isSpeaking
                            ? Icons.volume_off_rounded
                            : Icons.mic_none_rounded,
                        size: 32,
                        color: AppColors.darkBackground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (onWakeWordTap != null) ...[
              const SizedBox(width: 14),
              IconButton.outlined(
                onPressed: onWakeWordTap,
                tooltip: 'Listen for "Hey VISION" wake word',
                icon: const Icon(Icons.hearing_rounded),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          statusLabel ?? defaultLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isListening
                ? AppColors.success
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
