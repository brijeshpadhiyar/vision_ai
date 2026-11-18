import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/features/assistant/data/repositories/assistant_session_repository_impl.dart';
import 'package:vision_ai/features/assistant/domain/entities/assistant_readiness.dart';

/// Exposes the reactive [AssistantReadiness] state for the Assistant home screen.
final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantReadiness>(
      AssistantController.new,
    );

/// Controller managing user interactions on the VISION Assistant home screen.
class AssistantController extends Notifier<AssistantReadiness> {
  @override
  AssistantReadiness build() {
    final repository = ref.watch(assistantSessionRepositoryProvider);
    return repository.getInitialReadiness();
  }

  /// Handles taps on the microphone button placeholder without simulating voice capture.
  void onMicPlaceholderTapped() {
    ref
        .read(appLoggerProvider)
        .info(
          'Microphone placeholder tapped in Phase 1 (voice recognition not active).',
        );
    state = state.copyWith(
      mode: AssistantStandbyMode.micPlaceholderNotice,
      statusHeadline: 'Microphone Placeholder (Phase 1)',
      statusDetail: AppConstants.micPlaceholderMessage,
      interactionCount: state.interactionCount + 1,
    );
  }

  /// Resets the status banner back to standard standby information.
  void dismissNotice() {
    final initial = ref
        .read(assistantSessionRepositoryProvider)
        .getInitialReadiness();
    state = initial.copyWith(interactionCount: state.interactionCount);
  }
}
