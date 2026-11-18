import 'package:vision_ai/features/assistant/domain/entities/assistant_readiness.dart';

/// Domain contract for managing the Assistant session state.
abstract interface class AssistantSessionRepository {
  /// Returns the initial Phase 1 readiness state.
  AssistantReadiness getInitialReadiness();
}
