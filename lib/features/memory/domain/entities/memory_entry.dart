import 'package:material_ui/material_ui.dart';

/// Supported categories for explicit local user personalization memories.
enum MemoryCategory {
  responseStyle('Response Style'),
  frequentContacts('Contact Aliases'),
  commandPreferences('Command Preferences'),
  ongoingTasks('Ongoing Tasks');

  const MemoryCategory(this.displayName);

  final String displayName;
}

/// Persisted user preference or recurring personal context item.
@immutable
class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.enabled = true,
  });

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? 'responseStyle';
    final category = MemoryCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => MemoryCategory.responseStyle,
    );
    return MemoryEntry(
      id:
          json['id'] as String? ??
          'mem_${DateTime.now().microsecondsSinceEpoch}',
      category: category,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  final String id;
  final MemoryCategory category;
  final String title;
  final String content;
  final DateTime updatedAt;
  final bool enabled;

  MemoryEntry copyWith({
    MemoryCategory? category,
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? enabled,
  }) {
    return MemoryEntry(
      id: id,
      category: category ?? this.category,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': category.name,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'enabled': enabled,
  };
}
