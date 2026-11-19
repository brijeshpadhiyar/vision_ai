import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_orb.dart';

/// Backward-compatible wrapper around [VisionOrb] mapping legacy flags to
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
    this.isOffline = false,
    this.audioLevel = 0.0,
    this.onTap,
    this.riveConfig,
  });

  final double size;
  final bool isHighlighted;
  final bool isListening;
  final bool isSpeaking;
  final bool isThinking;
  final bool hasError;
  final bool isOffline;
  final double audioLevel;
  final VoidCallback? onTap;
  final VisionOrbRiveConfig? riveConfig;

  @override
  Widget build(BuildContext context) {
    final orbState = VisionOrbStateResolver.resolve(
      isListening: isListening,
      isThinking: isThinking,
      isSpeaking: isSpeaking,
      hasError: hasError,
      isOffline: isOffline,
    );

    return VisionOrb(
      size: size,
      state: orbState,
      audioLevel: audioLevel,
      onTap: onTap,
      riveConfig: riveConfig,
    );
  }
}
