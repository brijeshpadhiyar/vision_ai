import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/utils/network_status_service.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/chat/domain/services/provider_health_manager.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/provider_connection_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Developer diagnostics console displaying live provider health, latency metrics,
/// voice/automation readiness, sanitized error logs, and safe diagnostic export.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool? _isOnline;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final online = await ref.read(networkStatusServiceProvider).isOnline();
    await ref
        .read(voiceControllerProvider.notifier)
        .refreshAssistantCapabilities();
    if (mounted) {
      setState(() => _isOnline = online);
    }
  }

  Future<void> _exportSanitizedReport(
    BuildContext context,
    PerformanceSnapshot snapshot,
  ) async {
    final settings = ref.read(settingsControllerProvider);
    final voice = ref.read(voiceControllerProvider);
    final automation = ref.read(automationControllerProvider);
    final health = ref.read(providerHealthManagerProvider).snapshotAll();
    final connections = ref.read(providerConnectionControllerProvider);

    final report = <String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'activeProvider': settings.selectedAiProvider.id,
      'activeModel': settings.selectedModelId,
      'autoRoutingEnabled': settings.autoRoutingEnabled,
      'fallbackEnabled': settings.fallbackEnabled,
      'streamingEnabled': settings.streamingEnabled,
      'voiceLanguage': settings.selectedVoiceLanguage.localeCode,
      'networkOnline': _isOnline,
      'voice': <String, Object?>{
        'phase': voice.phase.name,
        'hasMicPermission': voice.hasMicPermission,
        'isDefaultAssistant': voice.isDefaultAssistant,
        'wakeWordArmed': voice.isWakeWordArmed,
        'wakeServiceRunning': voice.isWakeServiceRunning,
        'wakeMicActive': voice.isWakeMicActive,
      },
      'permissions': <String, Object?>{
        'callPhone': automation.hasCallPermission,
        'readContacts': automation.hasContactsPermission,
        'notificationConsent': settings.notificationListenerConsent,
      },
      'providerHealth': <String, Object?>{
        for (final provider in AiProviderType.values)
          provider.id: <String, Object?>{
            'circuit': health[provider]?.circuitState.name ?? 'healthy',
            'consecutiveFailures': health[provider]?.consecutiveFailures ?? 0,
            'avgLatencyMs': (health[provider]?.avgLatencyMs ?? 0).round(),
            'connectionState':
                connections[provider]?.connectionState.name ?? 'untested',
          },
      },
      'telemetry': snapshot.toSanitizedReport(),
    };

    final pretty = SecretRedactor.redact(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    await Clipboard.setData(ClipboardData(text: pretty));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sanitized diagnostic JSON copied to clipboard (no secrets or PII).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider);
    final settings = ref.watch(settingsControllerProvider);
    final voice = ref.watch(voiceControllerProvider);
    final automation = ref.watch(automationControllerProvider);
    final healthMap = ref.watch(providerHealthManagerProvider).snapshotAll();
    final connections = ref.watch(providerConnectionControllerProvider);

    return VisionScaffold(
      appBar: VisionAppBar(
        title: 'DEVELOPER DIAGNOSTICS',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh live status',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export sanitized report',
            onPressed: () => _exportSanitizedReport(context, telemetry),
          ),
        ],
      ),
      body: ListView(
        padding: VisionSpacing.screenPadding.copyWith(bottom: 120),
        children: [
          VisionGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistant & Connectivity Runtime',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    VisionStatusBadge(
                      label: settings.selectedAiProvider.displayName,
                      indicatorColor: VisionColors.accentPrimary,
                    ),
                    VisionStatusBadge(
                      label: settings.selectedModelId,
                      indicatorColor: VisionColors.accentSecondary,
                    ),
                    VisionStatusBadge(
                      label: _isOnline == null
                          ? 'Checking Network...'
                          : (_isOnline! ? 'Online' : 'Offline'),
                      indicatorColor: _isOnline == true
                          ? VisionColors.success
                          : VisionColors.warning,
                    ),
                    VisionStatusBadge(
                      label: 'Voice: ${voice.phase.name}',
                      indicatorColor: VisionColors.accentPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DiagRow(
                  'STT Language',
                  settings.selectedVoiceLanguage.displayName,
                ),
                _DiagRow(
                  'Microphone Permission',
                  voice.hasMicPermission ? 'Granted' : 'Missing',
                ),
                _DiagRow(
                  'Call Permission',
                  automation.hasCallPermission ? 'Granted' : 'Prompt/Dialer',
                ),
                _DiagRow(
                  'Contacts Permission',
                  automation.hasContactsPermission ? 'Granted' : 'Missing',
                ),
                _DiagRow(
                  'Wake Service',
                  voice.isWakeServiceRunning ? 'Running' : 'Stopped',
                ),
                _DiagRow(
                  'Default Assistant Role',
                  voice.isDefaultAssistant ? 'Active' : 'Not Default',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VisionGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latency & Execution Telemetry',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _DiagRow(
                  'Wake Word Detection (avg)',
                  '${telemetry.wakeDetectionCount} runs • ${telemetry.avgWakeDetectionMs.round()} ms',
                ),
                _DiagRow(
                  'Intent Parses (avg)',
                  '${telemetry.intentParseCount} runs • ${telemetry.avgIntentParseMicros.round()} µs',
                ),
                _DiagRow(
                  'Contact Resolution (avg)',
                  '${telemetry.contactResolutionCount} runs • ${telemetry.avgContactResolutionMs.round()} ms',
                ),
                _DiagRow(
                  'Local Commands',
                  '${telemetry.localCommandSuccessCount}/${telemetry.localCommandCount} handled',
                ),
                _DiagRow(
                  'Automation Actions',
                  '${telemetry.automationSuccessCount}/${telemetry.automationCount} ok • '
                      '${telemetry.avgAutomationMs.round()} ms avg',
                ),
                _DiagRow(
                  'AI First-Token Latency',
                  '${telemetry.avgAiFirstTokenMs.round()} ms avg',
                ),
                _DiagRow(
                  'AI Total Completion',
                  '${telemetry.aiSuccessCount}/${telemetry.aiRequestCount} ok • '
                      '${telemetry.avgAiTotalMs.round()} ms avg',
                ),
                _DiagRow(
                  'Voice STT / TTS Startup / E2E',
                  '${telemetry.avgVoiceSttMs.round()} ms / '
                      '${telemetry.avgTtsStartupMs.round()} ms / '
                      '${telemetry.avgEndToEndMs.round()} ms',
                ),
                _DiagRow(
                  'ASR Confidence (last utterance)',
                  voice.engineConfidence != null
                      ? '${(voice.engineConfidence! * 100).round()}% '
                            '(${voice.alternativeTranscripts.length} hypotheses)'
                      : 'Unavailable from speech engine '
                            '(${voice.alternativeTranscripts.length} hypotheses)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VisionGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Provider Circuit Health',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final provider in AiProviderType.values) ...[
                  _DiagRow(
                    provider.displayName,
                    '${connections[provider]?.connectionState.name ?? 'untested'} • '
                    'circuit: ${healthMap[provider]?.circuitState.name ?? 'healthy'} • '
                    'avg: ${(healthMap[provider]?.avgLatencyMs ?? 0).round()} ms',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          VisionGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sanitized Error Log (${telemetry.recentErrors.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (telemetry.recentErrors.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            ref.read(telemetryProvider.notifier).clearErrors(),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (telemetry.recentErrors.isEmpty)
                  Text(
                    'No errors recorded in this session.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  for (final err in telemetry.recentErrors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '[${err.source}] ${err.message}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: VisionColors.error),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VisionGlassButton(
            label: 'Copy Sanitized Diagnostic Report',
            icon: Icons.copy_all_rounded,
            onPressed: () => _exportSanitizedReport(context, telemetry),
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
