import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/controllers/routines_controller.dart';
import 'package:vision_ai/features/planner/domain/entities/planner_task.dart';
import 'package:vision_ai/features/planner/presentation/controllers/daily_planner_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

enum _PlannerFilter { all, pending, completed }

/// Local-first Daily Planner screen with tasks, priorities, optional reminder
/// times, and one-tap spoken Daily Briefing (Module 19 — v1.3 Wave 2).
class DailyPlannerScreen extends ConsumerStatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  ConsumerState<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends ConsumerState<DailyPlannerScreen> {
  _PlannerFilter _filter = _PlannerFilter.all;

  Future<void> _openAddTaskDialog() async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var priority = PlannerPriority.normal;
    int? dueHour;
    int? dueMinute;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('New Planner Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        hintText: 'e.g. Review project milestones',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Priority:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SegmentedButton<PlannerPriority>(
                            segments: const [
                              ButtonSegment(
                                value: PlannerPriority.low,
                                label: Text('Low'),
                              ),
                              ButtonSegment(
                                value: PlannerPriority.normal,
                                label: Text('Med'),
                              ),
                              ButtonSegment(
                                value: PlannerPriority.high,
                                label: Text('High'),
                              ),
                            ],
                            selected: <PlannerPriority>{priority},
                            onSelectionChanged: (sel) =>
                                setDialogState(() => priority = sel.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm_outlined),
                      title: Text(
                        dueHour != null && dueMinute != null
                            ? 'Reminder at ${dueHour!.toString().padLeft(2, '0')}:${dueMinute!.toString().padLeft(2, '0')}'
                            : 'Add Reminder Time (optional)',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dueHour = picked.hour;
                              dueMinute = picked.minute;
                            });
                          }
                        },
                        child: Text(dueHour != null ? 'Change' : 'Pick Time'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );

    final title = titleCtrl.text.trim();
    final notes = notesCtrl.text.trim();
    titleCtrl.dispose();
    notesCtrl.dispose();

    if (confirmed == true && title.isNotEmpty) {
      await ref
          .read(dailyPlannerControllerProvider.notifier)
          .addTask(
            title: title,
            notes: notes,
            dueHour: dueHour,
            dueMinute: dueMinute,
            priority: priority,
          );
    }
  }

  Future<void> _speakBriefing() async {
    final deviceStatus = ref.read(automationControllerProvider).deviceStatus;
    final routineCount = ref.read(routinesControllerProvider).length;
    final briefing = ref
        .read(dailyPlannerControllerProvider.notifier)
        .buildDailyBriefing(
          deviceStatus: deviceStatus,
          routineCount: routineCount,
        );
    await ref.read(voiceControllerProvider.notifier).speakReply(briefing);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(briefing)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(dailyPlannerControllerProvider);
    final controller = ref.read(dailyPlannerControllerProvider.notifier);
    final brightness = Theme.of(context).brightness;

    final pendingCount = tasks.where((t) => !t.completed).length;
    final completedCount = tasks.length - pendingCount;
    final visibleTasks = switch (_filter) {
      _PlannerFilter.all => tasks,
      _PlannerFilter.pending =>
        tasks.where((t) => !t.completed).toList(growable: false),
      _PlannerFilter.completed =>
        tasks.where((t) => t.completed).toList(growable: false),
    };

    return VisionScaffold(
      appBar: VisionAppBar(
        title: 'DAILY PLANNER',
        subtitle: '$pendingCount pending • $completedCount completed',
        actions: [
          if (completedCount > 0)
            IconButton(
              tooltip: 'Clear completed tasks',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: controller.clearCompleted,
            ),
          IconButton(
            tooltip: 'Add task',
            icon: const Icon(Icons.add_task_rounded),
            onPressed: _openAddTaskDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: VisionSpacing.navBarClearance,
        ),
        children: [
          // Summary & Speak Briefing Card
          VisionGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Today\'s Briefing',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _speakBriefing,
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Speak Briefing'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: tasks.isEmpty ? 0.0 : completedCount / tasks.length,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tasks.isEmpty
                          ? 'No tasks planned yet.'
                          : '$completedCount of ${tasks.length} tasks completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VisionColors.secondaryText(brightness),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openAddTaskDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Task'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          Row(
            children: [
              VisionGlassChip(
                label: 'All (${tasks.length})',
                selected: _filter == _PlannerFilter.all,
                onTap: () => setState(() => _filter = _PlannerFilter.all),
              ),
              const SizedBox(width: 8),
              VisionGlassChip(
                label: 'Pending ($pendingCount)',
                selected: _filter == _PlannerFilter.pending,
                onTap: () => setState(() => _filter = _PlannerFilter.pending),
              ),
              const SizedBox(width: 8),
              VisionGlassChip(
                label: 'Done ($completedCount)',
                selected: _filter == _PlannerFilter.completed,
                onTap: () => setState(() => _filter = _PlannerFilter.completed),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (visibleTasks.isEmpty)
            VisionGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: 36,
                    color: VisionColors.secondaryText(brightness),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No tasks in this view.',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            )
          else
            for (final task in visibleTasks) ...[
              VisionGlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: task.completed,
                    onChanged: (_) => controller.toggleCompleted(task.id),
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.notes.isNotEmpty) Text(task.notes),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          VisionStatusBadge(
                            label: task.priority.label,
                            indicatorColor: switch (task.priority) {
                              PlannerPriority.high => VisionColors.error,
                              PlannerPriority.normal =>
                                VisionColors.accentPrimary,
                              PlannerPriority.low => VisionColors.success,
                            },
                            compact: true,
                          ),
                          if (task.hasReminderTime)
                            VisionStatusBadge(
                              label: 'Due ${task.formattedDueTime}',
                              icon: Icons.alarm_rounded,
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete task',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => controller.deleteTask(task.id),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
