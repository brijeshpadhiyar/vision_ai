import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/features/assistant/domain/entities/assistant_readiness.dart';
import 'package:vision_ai/features/assistant/domain/repositories/assistant_session_repository.dart';

/// Provides the [AssistantSessionRepository] implementation.
final assistantSessionRepositoryProvider = Provider<AssistantSessionRepository>(
  (ref) {
    return const AssistantSessionRepositoryImpl();
  },
);

/// Phase 4 implementation of [AssistantSessionRepository].
class AssistantSessionRepositoryImpl implements AssistantSessionRepository {
  const AssistantSessionRepositoryImpl();

  @override
  AssistantReadiness getInitialReadiness() {
    return const AssistantReadiness(
      mode: AssistantStandbyMode.standby,
      statusHeadline: 'Voice, AI & Device Control Ready',
      statusDetail:
          'Speak in English, Hindi, or Gujarati, say "Hey VISION", or '
          'command Android actions like alarms, timers, calls, and apps.',
    );
  }
}
