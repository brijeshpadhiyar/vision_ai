import 'package:flutter/foundation.dart';

/// Supported Smart Home control backends (Module 23).
enum SmartHomeBackend {
  homeAssistant('Home Assistant', 'home_assistant'),
  httpWebhook('Local HTTP Webhook', 'http_webhook');

  const SmartHomeBackend(this.label, this.storageValue);

  final String label;
  final String storageValue;

  static SmartHomeBackend fromStorage(String? value) {
    for (final item in values) {
      if (item.storageValue == value) return item;
    }
    return SmartHomeBackend.httpWebhook;
  }
}

/// A user-configured local Smart Home device or scene.
@immutable
class SmartHomeDevice {
  const SmartHomeDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.backend,
    this.entityId = '',
    this.onWebhookUrl = '',
    this.offWebhookUrl = '',
    this.isOn = false,
  });

  factory SmartHomeDevice.fromJson(Map<String, dynamic> json) {
    return SmartHomeDevice(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Device',
      room: (json['room'] as String?) ?? 'Home',
      backend: SmartHomeBackend.fromStorage(json['backend'] as String?),
      entityId: (json['entityId'] as String?) ?? '',
      onWebhookUrl: (json['onWebhookUrl'] as String?) ?? '',
      offWebhookUrl: (json['offWebhookUrl'] as String?) ?? '',
      isOn: (json['isOn'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final String room;
  final SmartHomeBackend backend;

  /// Home Assistant entity ID (e.g., `light.living_room`, `switch.fan`, `scene.movie`).
  final String entityId;

  /// Local HTTP webhook URL for turning ON or activating a scene.
  final String onWebhookUrl;

  /// Optional local HTTP webhook URL for turning OFF.
  final String offWebhookUrl;

  final bool isOn;

  SmartHomeDevice copyWith({
    String? name,
    String? room,
    SmartHomeBackend? backend,
    String? entityId,
    String? onWebhookUrl,
    String? offWebhookUrl,
    bool? isOn,
  }) {
    return SmartHomeDevice(
      id: id,
      name: name ?? this.name,
      room: room ?? this.room,
      backend: backend ?? this.backend,
      entityId: entityId ?? this.entityId,
      onWebhookUrl: onWebhookUrl ?? this.onWebhookUrl,
      offWebhookUrl: offWebhookUrl ?? this.offWebhookUrl,
      isOn: isOn ?? this.isOn,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'room': room,
    'backend': backend.storageValue,
    'entityId': entityId,
    'onWebhookUrl': onWebhookUrl,
    'offWebhookUrl': offWebhookUrl,
    'isOn': isOn,
  };
}

/// Parsed Smart Home voice/chat command.
@immutable
class SmartHomeVoiceCommand {
  const SmartHomeVoiceCommand({
    required this.deviceQuery,
    required this.turnOn,
  });

  final String deviceQuery;
  final bool turnOn;
}
