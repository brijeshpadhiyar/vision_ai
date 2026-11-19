import 'package:flutter/foundation.dart';

/// Time-of-day schedule attached to an [AutomationRoutine] (Module 17).
@immutable
class RoutineSchedule {
  const RoutineSchedule({
    this.enabled = false,
    required this.hour,
    required this.minute,
    this.weekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
  });

  factory RoutineSchedule.fromJson(Map<String, dynamic> json) {
    return RoutineSchedule(
      enabled: (json['enabled'] as bool?) ?? false,
      hour: ((json['hour'] as num?)?.toInt() ?? 8).clamp(0, 23),
      minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
      weekdays:
          (json['weekdays'] as List<Object?>?)
              ?.whereType<num>()
              .map((n) => n.toInt().clamp(1, 7))
              .toList(growable: false) ??
          const <int>[1, 2, 3, 4, 5, 6, 7],
    );
  }

  final bool enabled;
  final int hour;
  final int minute;
  final List<int> weekdays;

  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays,
  };
}

/// User-defined multi-step Trusted Routine (Module 17).
@immutable
class AutomationRoutine {
  const AutomationRoutine({
    required this.id,
    required this.name,
    required this.triggerPhrases,
    required this.commandSteps,
    this.trusted = false,
    this.enabled = true,
    this.schedule,
  });

  factory AutomationRoutine.fromJson(Map<String, dynamic> json) {
    final scheduleRaw = json['schedule'];
    return AutomationRoutine(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Routine',
      triggerPhrases:
          (json['triggerPhrases'] as List<Object?>?)
              ?.whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      commandSteps:
          (json['commandSteps'] as List<Object?>?)
              ?.whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      trusted: (json['trusted'] as bool?) ?? false,
      enabled: (json['enabled'] as bool?) ?? true,
      schedule: scheduleRaw is Map<String, dynamic>
          ? RoutineSchedule.fromJson(scheduleRaw)
          : null,
    );
  }

  final String id;
  final String name;
  final List<String> triggerPhrases;
  final List<String> commandSteps;
  final bool trusted;
  final bool enabled;
  final RoutineSchedule? schedule;

  bool matchesVoiceInput(String input) {
    if (!enabled) return false;
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final nameLower = name.trim().toLowerCase();
    if (normalized == nameLower ||
        normalized == 'run $nameLower' ||
        normalized == 'start $nameLower' ||
        normalized == 'execute $nameLower') {
      return true;
    }
    for (final phrase in triggerPhrases) {
      final p = phrase.trim().toLowerCase();
      if (p.isNotEmpty &&
          (normalized == p ||
              normalized == 'run $p' ||
              normalized == 'start $p')) {
        return true;
      }
    }
    return false;
  }

  AutomationRoutine copyWith({
    String? name,
    List<String>? triggerPhrases,
    List<String>? commandSteps,
    bool? trusted,
    bool? enabled,
    RoutineSchedule? schedule,
    bool clearSchedule = false,
  }) {
    return AutomationRoutine(
      id: id,
      name: name ?? this.name,
      triggerPhrases: triggerPhrases ?? this.triggerPhrases,
      commandSteps: commandSteps ?? this.commandSteps,
      trusted: trusted ?? this.trusted,
      enabled: enabled ?? this.enabled,
      schedule: clearSchedule ? null : (schedule ?? this.schedule),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'triggerPhrases': triggerPhrases,
    'commandSteps': commandSteps,
    'trusted': trusted,
    'enabled': enabled,
    if (schedule != null) 'schedule': schedule!.toJson(),
  };
}
