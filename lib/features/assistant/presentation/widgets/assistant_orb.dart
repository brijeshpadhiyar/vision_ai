import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart';

/// Backward-compatible wrapper around [VisionAiOrb] mapping legacy flags to
/// [VisionOrbState].
class AssistantOrb extends StatelessWidget {
  const AssistantOrb({
    super.key,
    this.size = AppConstants.orbBaseSize,
    this.isHighlighted = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.isThinking = false,
    this.hasError = false,
    this.audioLevel = 0.0,
    this.onTap,
  });

  final double size;
  final bool isHighlighted;
  final bool isListening;
  final bool isSpeaking;
  final bool isThinking;
  final bool hasError;
  final double audioLevel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final orbState = hasError
        ? VisionOrbState.error
        : isListening
        ? VisionOrbState.listening
        : isThinking
        ? VisionOrbState.thinking
        : isSpeaking
        ? VisionOrbState.speaking
        : VisionOrbState.idle;

    return VisionAiOrb(
      size: size,
      state: orbState,
      audioLevel: audioLevel,
      onTap: onTap,
    );
  }
}
