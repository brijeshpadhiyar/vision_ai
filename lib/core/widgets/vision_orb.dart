import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart';

export 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart'
    show VisionOrbState;

/// Reusable 6-state animated AI orb (`idle`, `listening`, `thinking`,
/// `speaking`, `error`, `offline`) themed with Midnight Violet & Pearl Lavender.
class VisionOrb extends StatelessWidget {
  const VisionOrb({
    super.key,
    this.size = AppConstants.orbBaseSize,
    this.state = VisionOrbState.idle,
    this.audioLevel = 0.0,
    this.onTap,
    this.semanticLabel = 'VISION AI interactive orb',
  });

  final double size;
  final VisionOrbState state;
  final double audioLevel;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return VisionAiOrb(
      size: size,
      state: state,
      audioLevel: audioLevel,
      onTap: onTap,
      semanticLabel: semanticLabel,
    );
  }
}
