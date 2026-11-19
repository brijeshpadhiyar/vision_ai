import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/help/domain/entities/help_guide_catalog.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Interactive Help, Full Application Guide & Settings Search Hub (`/help`).
///
/// Responsive Liquid Glass layout adapting cleanly between compact phones
/// (single column) and wide/tablet screens (two-column grid).
class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  HelpCategory _selectedCategory = HelpCategory.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToTarget(HelpActionTarget target) {
    final path = target.routePath;
    if (path.startsWith('/settings') ||
        path == '/chat' ||
        path == '/automation') {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final settings = ref.watch(settingsControllerProvider);
    final voiceState = ref.watch(voiceControllerProvider);
    final automationState = ref.watch(automationControllerProvider);
    final keyMap =
        ref.watch(apiKeyStatusControllerProvider).asData?.value ??
        const <AiProviderType, bool>{};
    final hasAnyAiReady =
        !settings.selectedAiProvider.requiresApiKey ||
        keyMap.values.any((configured) => configured);
    final deviceLabel =
        automationState.deviceStatus?.deviceDisplayName ?? 'Android Device';

    final filteredTopics = HelpGuideCatalog.searchTopics(
      _query,
      category: _selectedCategory,
    );
    final matchingSettings = _query.trim().isNotEmpty
        ? HelpGuideCatalog.searchSettings(_query)
        : const <SettingSearchEntry>[];

    return VisionScaffold(
      appBar: VisionAppBar(
        title: 'HELP & USER GUIDE',
        subtitle: 'Full App Guidance • $deviceLabel',
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          return ListView(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: VisionSpacing.navBarClearance,
            ),
            children: [
              // 1. Live Search Bar
              VisionGlassInput(
                controller: _searchController,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search any feature, setting, or command (e.g. API key, OCR, Gujarati)...',
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),

              // 2. Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in HelpCategory.values) ...[
                      VisionGlassChip(
                        label: category.label,
                        icon: category.icon,
                        selected: _selectedCategory == category,
                        onTap: () =>
                            setState(() => _selectedCategory = category),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Instant Setting Matches when searching
              if (matchingSettings.isNotEmpty) ...[
                Text(
                  'MATCHING SETTINGS & SHORTCUTS (${matchingSettings.length})',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: VisionColors.primaryAccent(brightness),
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                VisionGlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final entry in matchingSettings)
                        ListTile(
                          leading: Icon(
                            entry.icon,
                            color: VisionColors.primaryAccent(brightness),
                          ),
                          title: Text(entry.title),
                          subtitle: Text(
                            '${entry.sectionLabel} • ${entry.subtitle}',
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () => _navigateToTarget(entry.target),
                            child: const Text('Open'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Live Setup Readiness Checklist (shown when not filtering)
              if (_query.trim().isEmpty &&
                  (_selectedCategory == HelpCategory.all ||
                      _selectedCategory == HelpCategory.gettingStarted)) ...[
                _SetupReadinessCard(
                  hasAiReady: hasAnyAiReady,
                  hasMicPermission: voiceState.hasMicPermission,
                  isDefaultAssistant: voiceState.isDefaultAssistant,
                  isBatteryUnrestricted:
                      automationState
                          .deviceStatus
                          ?.isIgnoringBatteryOptimizations ??
                      false,
                  onOpenTarget: _navigateToTarget,
                ),
                const SizedBox(height: 16),
              ],

              // 5. Step-by-Step Guides Grid / List
              if (filteredTopics.isEmpty)
                VisionGlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 36,
                        color: VisionColors.secondaryText(brightness),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No guide matches "$_query".',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try keywords like "API key", "voice", "OCR", "web", "routine", "privacy", or "planner".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VisionColors.secondaryText(brightness),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isWide)
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final topic in filteredTopics)
                      SizedBox(
                        width: (constraints.maxWidth - 14) / 2,
                        child: _HelpTopicCard(
                          topic: topic,
                          initiallyExpanded: _query.trim().isNotEmpty,
                          onOpenAction: () =>
                              _navigateToTarget(topic.actionTarget),
                        ),
                      ),
                  ],
                )
              else
                for (final topic in filteredTopics) ...[
                  _HelpTopicCard(
                    topic: topic,
                    initiallyExpanded: _query.trim().isNotEmpty,
                    onOpenAction: () => _navigateToTarget(topic.actionTarget),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _SetupReadinessCard extends StatelessWidget {
  const _SetupReadinessCard({
    required this.hasAiReady,
    required this.hasMicPermission,
    required this.isDefaultAssistant,
    required this.isBatteryUnrestricted,
    required this.onOpenTarget,
  });

  final bool hasAiReady;
  final bool hasMicPermission;
  final bool isDefaultAssistant;
  final bool isBatteryUnrestricted;
  final ValueChanged<HelpActionTarget> onOpenTarget;

  @override
  Widget build(BuildContext context) {
    final completed = <bool>[
      hasAiReady,
      hasMicPermission,
      isDefaultAssistant,
      isBatteryUnrestricted,
    ].where((ok) => ok).length;

    return VisionGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Setup Readiness',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              VisionStatusBadge(
                label: '$completed / 4 Ready',
                indicatorColor: completed == 4
                    ? VisionColors.success
                    : VisionColors.warning,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ReadinessRow(
            label: 'AI Engine (API Key or On-Device Edge AI)',
            ready: hasAiReady,
            onTap: () => onOpenTarget(HelpActionTarget.openSettingsAi),
          ),
          _ReadinessRow(
            label: 'Microphone Permission for Voice & Wake-Word',
            ready: hasMicPermission,
            onTap: () => onOpenTarget(HelpActionTarget.openSettingsSystem),
          ),
          _ReadinessRow(
            label: 'Android Default Digital Assistant Role',
            ready: isDefaultAssistant,
            onTap: () => onOpenTarget(HelpActionTarget.openSettingsSystem),
          ),
          _ReadinessRow(
            label: 'Unrestricted Background Battery',
            ready: isBatteryUnrestricted,
            onTap: () => onOpenTarget(HelpActionTarget.openSettingsSystem),
          ),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.ready,
    required this.onTap,
  });

  final String label;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: VisionRadii.smBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18,
              color: ready ? VisionColors.success : VisionColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(
              ready ? 'Ready' : 'Configure',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ready ? VisionColors.success : VisionColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpTopicCard extends StatelessWidget {
  const _HelpTopicCard({
    required this.topic,
    required this.initiallyExpanded,
    required this.onOpenAction,
  });

  final HelpGuideTopic topic;
  final bool initiallyExpanded;
  final VoidCallback onOpenAction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = VisionColors.primaryAccent(brightness);

    return VisionGlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Icon(topic.icon, size: 18, color: accent),
          ),
          title: Text(
            topic.title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            topic.subtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: VisionColors.secondaryText(brightness)),
          ),
          children: [
            const Divider(height: 12),
            for (var i = 0; i < topic.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}.',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        topic.steps[i],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            if (topic.exampleCommands.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Try saying or typing (tap to copy):',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VisionColors.secondaryText(brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final cmd in topic.exampleCommands)
                    ActionChip(
                      avatar: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(
                        '"$cmd"',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: cmd));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied example: "$cmd"'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onOpenAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(topic.actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
