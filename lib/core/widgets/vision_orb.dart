import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_orb.dart'
    as assistant_orb;

export 'package:vision_ai/features/assistant/presentation/widgets/vision_orb.dart'
    show
        ConnectedVisionOrb,
        VisionOrbRiveConfig,
        VisionOrbState,
        VisionOrbStateResolver;

/// Reusable 6-state animated AI orb (`idle`, `listening`, `thinking`,
/// `speaking`, `error`, `offline`) delegating to the Rive-ready assistant
/// [assistant_orb.VisionOrb].
class VisionOrb extends StatelessWidget {
  const VisionOrb({
    super.key,
    this.size = AppConstants.orbBaseSize,
    this.state = assistant_orb.VisionOrbState.idle,
    this.audioLevel = 0.0,
    this.onTap,
    this.semanticLabel = 'VISION AI interactive orb',
    this.riveConfig,
  });

  final double size;
  final assistant_orb.VisionOrbState state;
  final double audioLevel;
  final VoidCallback? onTap;
  final String semanticLabel;
  final assistant_orb.VisionOrbRiveConfig? riveConfig;

  @override
  Widget build(BuildContext context) {
    return assistant_orb.VisionOrb(
      size: size,
      state: state,
      audioLevel: audioLevel,
      onTap: onTap,
      semanticLabel: semanticLabel,
      riveConfig: riveConfig,
    );
  }
}
