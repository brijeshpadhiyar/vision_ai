import 'package:material_ui/material_ui.dart';

/// Represents the current Phase 1 standby state of the VISION assistant UI.
enum AssistantStandbyMode {
  /// Default idle standby state.
  standby,

  /// State displayed when the user taps the Phase 1 microphone placeholder.
  micPlaceholderNotice,
}

/// Immutable state model for the VISION Assistant home screen in Phase 1.
@immutable
class AssistantReadiness {
  const AssistantReadiness({
    required this.mode,
    required this.statusHeadline,
    required this.statusDetail,
    this.interactionCount = 0,
  });

  final AssistantStandbyMode mode;
  final String statusHeadline;
  final String statusDetail;
  final int interactionCount;

  AssistantReadiness copyWith({
    AssistantStandbyMode? mode,
    String? statusHeadline,
    String? statusDetail,
    int? interactionCount,
  }) {
    return AssistantReadiness(
      mode: mode ?? this.mode,
      statusHeadline: statusHeadline ?? this.statusHeadline,
      statusDetail: statusDetail ?? this.statusDetail,
      interactionCount: interactionCount ?? this.interactionCount,
    );
  }
}
