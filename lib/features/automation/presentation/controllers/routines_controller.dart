import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/automation_routine.dart';

/// Persisted user-defined Trusted Routines controller (Module 17).
final routinesControllerProvider =
    NotifierProvider<RoutinesController, List<AutomationRoutine>>(
      RoutinesController.new,
    );

class RoutinesController extends Notifier<List<AutomationRoutine>> {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.automationMethodChannel,
  );

  @override
  List<AutomationRoutine> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.automationRoutines);
    return _decode(raw);
  }

  /// Finds the first enabled routine matching a spoken or typed [input].
  AutomationRoutine? findByVoiceTrigger(String input) {
    for (final routine in state) {
      if (routine.matchesVoiceInput(input)) {
        return routine;
      }
    }
    return null;
  }

  /// Creates or updates a routine and syncs its Android schedule if configured.
  Future<void> saveRoutine(AutomationRoutine routine) async {
    final next = <AutomationRoutine>[
      for (final existing in state)
        if (existing.id != routine.id) existing,
      routine,
    ];
    state = List<AutomationRoutine>.unmodifiable(next);
    await _persist(next);
    await _syncNativeSchedule(routine);
  }

  /// Deletes a routine by [routineId] and cancels any scheduled Android alarm.
  Future<void> deleteRoutine(String routineId) async {
    final next = state
        .where((r) => r.id != routineId)
        .toList(growable: false);
    state = List<AutomationRoutine>.unmodifiable(next);
    await _persist(next);
    await _cancelNativeSchedule(routineId);
  }

  /// Toggles whether a routine is marked trusted.
  Future<void> setRoutineTrusted(String routineId, {required bool trusted}) async {
    final idx = state.indexWhere((r) => r.id == routineId);
    if (idx == -1) return;
    final updated = state[idx].copyWith(trusted: trusted);
    await saveRoutine(updated);
  }

  Future<void> _syncNativeSchedule(AutomationRoutine routine) async {
    final schedule = routine.schedule;
    if (!routine.enabled || schedule == null || !schedule.enabled) {
      await _cancelNativeSchedule(routine.id);
      return;
    }
    try {
      await _channel.invokeMethod<bool>(
        'scheduleRoutineAlarm',
        <String, Object>{
          'routineId': routine.id,
          'routineName': routine.name,
          'hour': schedule.hour,
          'minute': schedule.minute,
        },
      );
    } on MissingPluginException {
      // Ignore on non-Android test hosts.
    } on PlatformException {
      // Best-effort schedule sync.
    }
  }

  Future<void> _cancelNativeSchedule(String routineId) async {
    try {
      await _channel.invokeMethod<bool>(
        'cancelRoutineAlarm',
        <String, Object>{'routineId': routineId},
      );
    } on MissingPluginException {
      // Ignore on non-Android test hosts.
    } on PlatformException {
      // Best-effort cancel.
    }
  }

  Future<void> _persist(List<AutomationRoutine> routines) async {
    final encoded = jsonEncode(
      routines.map((r) => r.toJson()).toList(growable: false),
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(StorageKeys.automationRoutines, encoded);
  }

  static List<AutomationRoutine> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <AutomationRoutine>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return const <AutomationRoutine>[];
      }
      return List<AutomationRoutine>.unmodifiable(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(AutomationRoutine.fromJson)
            .where((r) => r.id.isNotEmpty && r.commandSteps.isNotEmpty),
      );
    } on FormatException {
      return const <AutomationRoutine>[];
    }
  }
}
