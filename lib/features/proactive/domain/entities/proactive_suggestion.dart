import 'package:material_ui/material_ui.dart';

/// Action kind triggered when a user taps a Proactive Intelligence suggestion card.
enum ProactiveActionType { speakBriefing, openRoute, openBatterySettings }

/// A contextual, locally generated smart suggestion displayed on the Home screen.
@immutable
class ProactiveSuggestion {
  const ProactiveSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.actionType,
    this.routePath,
    this.priority = 50,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final ProactiveActionType actionType;
  final String? routePath;

  /// Higher priority suggestions surface first.
  final int priority;
}
