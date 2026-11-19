import 'package:flutter/foundation.dart';

/// A locally saved reusable code snippet in the Developer Assistant Vault (Module 26).
@immutable
class DeveloperSnippet {
  const DeveloperSnippet({
    required this.id,
    required this.title,
    required this.language,
    required this.code,
    required this.createdAtMillis,
  });

  factory DeveloperSnippet.fromJson(Map<String, dynamic> json) {
    return DeveloperSnippet(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Snippet',
      language: (json['language'] as String?) ?? 'dart',
      code: (json['code'] as String?) ?? '',
      createdAtMillis: (json['createdAtMillis'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final String language;
  final String code;
  final int createdAtMillis;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'language': language,
    'code': code,
    'createdAtMillis': createdAtMillis,
  };
}
