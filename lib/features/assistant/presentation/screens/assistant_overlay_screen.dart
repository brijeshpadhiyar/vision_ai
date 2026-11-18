import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/features/assistant/presentation/screens/assistant_experience_screen.dart';

/// Translucent floating assistant experience used by `AssistantOverlayActivity`
/// when triggered via "Hey VISION" wake word or Android's Assist gesture.
class AssistantOverlayScreen extends StatelessWidget {
  const AssistantOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AssistantExperienceScreen(
      isSystemOverlay: true,
      autoListenOnOpen: true,
    );
  }
}
