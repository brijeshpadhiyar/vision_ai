import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/features/automation/domain/entities/automation_routine.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/controllers/routines_controller.dart';

/// Displays user-defined Trusted Routines with quick Run, Schedule badge, Trust toggle,
/// and Create/Delete controls inside [AutomationScreen] (Module 17).
class RoutinesSectionCard extends ConsumerWidget {
  const RoutinesSectionCard({super.key});

  Future<void> _openCreateRoutineDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    final triggersCtrl = TextEditingController();
    final stepsCtrl = TextEditingController();
    var trusted = false;
    var scheduleEnabled = false;
    var scheduleHour = 8;
    var scheduleMinute = 0;

    final created = await showDialog<AutomationRoutine>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('New Trusted Routine'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Routine Name',
                        hintText: 'e.g. Good Night',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: triggersCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Voice Triggers (comma-separated)',
                        hintText: 'e.g. bedtime, sleep mode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stepsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Command Steps (one per line)',
                        hintText: 'turn off flashlight\nset alarm for 7 am',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Trust this routine'),
                      subtitle: const Text(
                        'Skip confirmation for routine steps',
                      ),
                      value: trusted,
                      onChanged: (v) => setDialogState(() => trusted = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Daily Schedule'),
                      subtitle: Text(
                        scheduleEnabled
                            ? 'Scheduled at ${scheduleHour.toString().padLeft(2, '0')}:${scheduleMinute.toString().padLeft(2, '0')}'
                            : 'Manual / voice trigger only',
                      ),
                      value: scheduleEnabled,
                      onChanged: (v) async {
                        if (v) {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                              hour: scheduleHour,
                              minute: scheduleMinute,
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              scheduleHour = picked.hour;
                              scheduleMinute = picked.minute;
                              scheduleEnabled = true;
                            });
                          }
                        } else {
                          setDialogState(() => scheduleEnabled = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final steps = stepsCtrl.text
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(growable: false);
                    if (name.isEmpty || steps.isEmpty) return;
                    final triggers = triggersCtrl.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(growable: false);
                    Navigator.of(dialogContext).pop(
                      AutomationRoutine(
                        id: 'rt_${DateTime.now().microsecondsSinceEpoch}',
                        name: name,
                        triggerPhrases: triggers,
                        commandSteps: steps,
                        trusted: trusted,
                        schedule: scheduleEnabled
                            ? RoutineSchedule(
                                enabled: true,
                                hour: scheduleHour,
                                minute: scheduleMinute,
                              )
                            : null,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    triggersCtrl.dispose();
    stepsCtrl.dispose();

    if (created != null) {
      await ref.read(routinesControllerProvider.notifier).saveRoutine(created);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesControllerProvider);
    final brightness = Theme.of(context).brightness;

    return VisionGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trusted Routines',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: VisionColors.primaryText(brightness),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: () => _openCreateRoutineDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chain multi-step voice commands into reusable routines with optional daily schedules.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: VisionColors.secondaryText(brightness),
            ),
          ),
          if (routines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'No routines yet. Tap Add to create your first routine.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: VisionColors.secondaryText(brightness),
                ),
              ),
            )
          else
            for (final routine in routines) ...[
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(routine.name),
                subtitle: Text(
                  '${routine.commandSteps.length} step${routine.commandSteps.length == 1 ? '' : 's'}'
                  '${routine.schedule?.enabled == true ? ' • Daily ${routine.schedule!.formattedTime}' : ''}'
                  '${routine.trusted ? ' • Trusted' : ' • Confirm'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Run routine',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () async {
                        final res = await ref
                            .read(automationControllerProvider.notifier)
                            .executeRoutine(routine);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res.summary)),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete routine',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => ref
                          .read(routinesControllerProvider.notifier)
                          .deleteRoutine(routine.id),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
