import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/planner/domain/entities/planner_task.dart';

/// Persisted local-first Daily Planner controller (Module 19 — v1.3 Wave 2).
final dailyPlannerControllerProvider =
    NotifierProvider<DailyPlannerController, List<PlannerTask>>(
      DailyPlannerController.new,
    );

class DailyPlannerController extends Notifier<List<PlannerTask>> {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.automationMethodChannel,
  );

  @override
  List<PlannerTask> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.dailyPlannerTasks);
    return _sortTasks(_decode(raw));
  }

  Future<PlannerTask> addTask({
    required String title,
    String notes = '',
    int? dueHour,
    int? dueMinute,
    PlannerPriority priority = PlannerPriority.normal,
  }) async {
    final task = PlannerTask(
      id: 'task_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      notes: notes.trim(),
      dueHour: dueHour,
      dueMinute: dueMinute,
      priority: priority,
      createdAt: DateTime.now(),
    );
    final next = _sortTasks(<PlannerTask>[...state, task]);
    state = next;
    await _persist(next);
    if (task.hasReminderTime) {
      await _scheduleReminder(task);
    }
    return task;
  }

  Future<void> toggleCompleted(String taskId) async {
    final next = _sortTasks(<PlannerTask>[
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(completed: !task.completed)
        else
          task,
    ]);
    state = next;
    await _persist(next);
    final updated = next.where((t) => t.id == taskId).firstOrNull;
    if (updated != null && updated.completed) {
      await _cancelReminder(taskId);
    }
  }

  Future<void> deleteTask(String taskId) async {
    final next = state.where((t) => t.id != taskId).toList(growable: false);
    state = List<PlannerTask>.unmodifiable(next);
    await _persist(next);
    await _cancelReminder(taskId);
  }

  Future<void> clearCompleted() async {
    final removed = state.where((t) => t.completed).toList(growable: false);
    final next = state.where((t) => !t.completed).toList(growable: false);
    state = List<PlannerTask>.unmodifiable(next);
    await _persist(next);
    for (final task in removed) {
      await _cancelReminder(task.id);
    }
  }

  /// Generates a concise, voice-friendly Daily Briefing summarizing pending
  /// tasks, high-priority items, routines, and live device battery/network state.
  String buildDailyBriefing({
    DeviceStatusSnapshot? deviceStatus,
    int routineCount = 0,
  }) {
    final pending = state.where((t) => !t.completed).toList(growable: false);
    final highPriority = pending
        .where((t) => t.priority == PlannerPriority.high)
        .toList(growable: false);
    final completedCount = state.length - pending.length;

    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Good morning.'
        : hour < 17
        ? 'Good afternoon.'
        : 'Good evening.';

    final parts = <String>[salutation];
    if (pending.isEmpty) {
      parts.add(
        completedCount > 0
            ? 'All $completedCount of your planned tasks are completed.'
            : 'Your daily planner is clear with no pending tasks.',
      );
    } else {
      parts.add(
        'You have ${pending.length} pending task${pending.length == 1 ? '' : 's'}'
        '${highPriority.isNotEmpty ? ', including ${highPriority.length} high priority' : ''}.',
      );
      final topTitles = pending
          .take(3)
          .map(
            (t) => t.hasReminderTime
                ? '${t.title} at ${t.formattedDueTime}'
                : t.title,
          )
          .join('; ');
      parts.add('Up next: $topTitles.');
    }
    if (routineCount > 0) {
      parts.add(
        'You have $routineCount trusted routine${routineCount == 1 ? '' : 's'} configured.',
      );
    }
    if (deviceStatus != null && deviceStatus.batteryLevel >= 0) {
      parts.add(
        'Battery is at ${deviceStatus.batteryLevel}% on ${deviceStatus.networkType}.',
      );
    }
    return parts.join(' ');
  }

  Future<void> _scheduleReminder(PlannerTask task) async {
    try {
      await _channel.invokeMethod<bool>(
        'scheduleRoutineAlarm',
        <String, Object>{
          'routineId': task.id,
          'routineName': 'Reminder: ${task.title}',
          'hour': task.dueHour!,
          'minute': task.dueMinute!,
        },
      );
    } on MissingPluginException {
      // Ignore outside Android.
    } on PlatformException {
      // Best-effort reminder schedule.
    }
  }

  Future<void> _cancelReminder(String taskId) async {
    try {
      await _channel.invokeMethod<bool>(
        'cancelRoutineAlarm',
        <String, Object>{'routineId': taskId},
      );
    } on MissingPluginException {
      // Ignore outside Android.
    } on PlatformException {
      // Best-effort cancel.
    }
  }

  Future<void> _persist(List<PlannerTask> tasks) async {
    final encoded = jsonEncode(
      tasks.map((t) => t.toJson()).toList(growable: false),
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(StorageKeys.dailyPlannerTasks, encoded);
  }

  static List<PlannerTask> _sortTasks(List<PlannerTask> tasks) {
    final sorted = List<PlannerTask>.of(tasks)
      ..sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        if (a.priority.weight != b.priority.weight) {
          return b.priority.weight.compareTo(a.priority.weight);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return List<PlannerTask>.unmodifiable(sorted);
  }

  static List<PlannerTask> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <PlannerTask>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const <PlannerTask>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PlannerTask.fromJson)
          .where((t) => t.id.isNotEmpty && t.title.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const <PlannerTask>[];
    }
  }
}
