import 'package:flutter/foundation.dart';

/// Priority level for a [PlannerTask] (Module 19 — Daily Planner).
enum PlannerPriority {
  low('Low', 0),
  normal('Normal', 1),
  high('High', 2);

  const PlannerPriority(this.label, this.weight);

  final String label;
  final int weight;

  static PlannerPriority fromName(String? raw) {
    for (final value in PlannerPriority.values) {
      if (value.name == raw) return value;
    }
    return PlannerPriority.normal;
  }
}

/// Local-first task & reminder entity for VISION AI Daily Planner (Module 19).
@immutable
class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.title,
    this.notes = '',
    this.dueHour,
    this.dueMinute,
    this.priority = PlannerPriority.normal,
    this.completed = false,
    required this.createdAt,
  });

  factory PlannerTask.fromJson(Map<String, dynamic> json) {
    return PlannerTask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      dueHour: (json['dueHour'] as num?)?.toInt(),
      dueMinute: (json['dueMinute'] as num?)?.toInt(),
      priority: PlannerPriority.fromName(json['priority'] as String?),
      completed: (json['completed'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String title;
  final String notes;
  final int? dueHour;
  final int? dueMinute;
  final PlannerPriority priority;
  final bool completed;
  final DateTime createdAt;

  bool get hasReminderTime => dueHour != null && dueMinute != null;

  String get formattedDueTime {
    if (!hasReminderTime) return '';
    return '${dueHour!.toString().padLeft(2, '0')}:${dueMinute!.toString().padLeft(2, '0')}';
  }

  PlannerTask copyWith({
    String? title,
    String? notes,
    int? dueHour,
    int? dueMinute,
    bool clearDueTime = false,
    PlannerPriority? priority,
    bool? completed,
  }) {
    return PlannerTask(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueHour: clearDueTime ? null : (dueHour ?? this.dueHour),
      dueMinute: clearDueTime ? null : (dueMinute ?? this.dueMinute),
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'notes': notes,
    if (dueHour != null) 'dueHour': dueHour,
    if (dueMinute != null) 'dueMinute': dueMinute,
    'priority': priority.name,
    'completed': completed,
    'createdAt': createdAt.toIso8601String(),
  };
}
