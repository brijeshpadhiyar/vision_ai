import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/services/provider_health_manager.dart';
import 'package:vision_ai/features/chat/domain/services/task_complexity_classifier.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Computes ordered provider priority lists while honoring user preference,
/// live health state, and task complexity without unnecessary provider hops.
abstract final class ProviderFallbackManager {
  /// Orders [configuredEnabledProviders] cleanly starting from [preferredProvider].
  ///
  /// [preferredProvider] always stays primary (manual selection). When
  /// [fallbackEnabled] is true, healthy enabled alternatives are appended as
  /// ordered fallback targets.
  static List<AiProviderType> orderCandidates({
    required AiProviderType preferredProvider,
    required Set<AiProviderType> configuredEnabledProviders,
    required bool fallbackEnabled,
    required TaskComplexityTier complexity,
    ProviderHealthManager? healthManager,
  }) {
    if (configuredEnabledProviders.isEmpty) {
      return const <AiProviderType>[];
    }

    final baseOrder = _baselineOrder(
      preferredProvider: preferredProvider,
      complexity: complexity,
    );

    final available = baseOrder
        .where(configuredEnabledProviders.contains)
        .toList(growable: true);

    if (available.isEmpty) {
      return const <AiProviderType>[];
    }

    if (healthManager != null) {
      final now = DateTime.now();
      final healthy = <AiProviderType>[];
      final resting = <AiProviderType>[];
      for (final provider in available) {
        if (healthManager.isProviderAvailable(provider, now: now)) {
          healthy.add(provider);
        } else {
          resting.add(provider);
        }
      }
      // Only reorder out of preferred provider if cooldown active and fallback enabled
      if (healthy.isNotEmpty) {
        available
          ..clear()
          ..addAll(healthy)
          ..addAll(resting);
      }
    }

    if (!fallbackEnabled && available.length > 1) {
      // Keep only the top resolved candidate when user explicitly disabled fallback.
      return <AiProviderType>[available.first];
    }

    return List<AiProviderType>.unmodifiable(available);
  }

  static List<AiProviderType> _baselineOrder({
    required AiProviderType preferredProvider,
    required TaskComplexityTier complexity,
  }) {
    final fallbackTail = switch (complexity) {
      TaskComplexityTier.deepReasoningCoding => const <AiProviderType>[
        AiProviderType.claude,
        AiProviderType.openAi,
        AiProviderType.gemini,
      ],
      TaskComplexityTier.balancedMultilingual => const <AiProviderType>[
        AiProviderType.gemini,
        AiProviderType.openAi,
        AiProviderType.claude,
      ],
      TaskComplexityTier.simpleFast => const <AiProviderType>[
        AiProviderType.gemini,
        AiProviderType.openAi,
        AiProviderType.claude,
      ],
    };

    return <AiProviderType>[
      preferredProvider,
      for (final p in fallbackTail)
        if (p != preferredProvider) p,
    ];
  }

  /// Determines whether fallback to the next candidate should be attempted
  /// for a failure on the current provider.
  static bool shouldFallbackForError(AIError error) {
    if (error.kind == AIErrorKind.cancelled) return false;
    return true;
  }
}
