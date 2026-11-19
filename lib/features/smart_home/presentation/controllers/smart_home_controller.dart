import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/smart_home/domain/entities/smart_home_device.dart';

/// State for Module 23: Smart Home Integration.
@immutable
class SmartHomeState {
  const SmartHomeState({
    this.devices = const <SmartHomeDevice>[],
    this.haBaseUrl = '',
    this.hasHaToken = false,
    this.isBusy = false,
    this.statusMessage,
  });

  final List<SmartHomeDevice> devices;
  final String haBaseUrl;
  final bool hasHaToken;
  final bool isBusy;
  final String? statusMessage;

  SmartHomeState copyWith({
    List<SmartHomeDevice>? devices,
    String? haBaseUrl,
    bool? hasHaToken,
    bool? isBusy,
    String? statusMessage,
    bool clearStatus = false,
  }) {
    return SmartHomeState(
      devices: devices ?? this.devices,
      haBaseUrl: haBaseUrl ?? this.haBaseUrl,
      hasHaToken: hasHaToken ?? this.hasHaToken,
      isBusy: isBusy ?? this.isBusy,
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

/// Optional HTTP client override for unit tests.
final smartHomeHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Controller for Module 23: Smart Home devices, Home Assistant REST API,
/// local HTTP webhooks, and voice command matching.
class SmartHomeController extends Notifier<SmartHomeState> {
  static final RegExp _turnOnRegex = RegExp(
    r'^(?:turn\s+on|switch\s+on|enable|activate|run\s+scene)\s+(.+)$',
    caseSensitive: false,
  );

  static final RegExp _turnOffRegex = RegExp(
    r'^(?:turn\s+off|switch\s+off|disable)\s+(.+)$',
    caseSensitive: false,
  );

  @override
  SmartHomeState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final haUrl = prefs.getString(StorageKeys.smartHomeHaBaseUrl) ?? '';
    final rawDevices = prefs.getString(StorageKeys.smartHomeDevices);
    final devices = <SmartHomeDevice>[];

    if (rawDevices != null && rawDevices.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDevices);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              devices.add(SmartHomeDevice.fromJson(item));
            }
          }
        }
      } on FormatException {
        // Ignore malformed local JSON.
      }
    }

    Future<void>.microtask(_refreshTokenStatus);
    return SmartHomeState(devices: devices, haBaseUrl: haUrl);
  }

  /// Parses voice/chat commands such as `"turn on living room light"` or `"turn off fan"`.
  static SmartHomeVoiceCommand? parseVoiceCommand(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final onMatch = _turnOnRegex.firstMatch(trimmed);
    if (onMatch != null) {
      final target = (onMatch.group(1) ?? '').trim();
      if (target.isNotEmpty) {
        return SmartHomeVoiceCommand(deviceQuery: target, turnOn: true);
      }
    }

    final offMatch = _turnOffRegex.firstMatch(trimmed);
    if (offMatch != null) {
      final target = (offMatch.group(1) ?? '').trim();
      if (target.isNotEmpty) {
        return SmartHomeVoiceCommand(deviceQuery: target, turnOn: false);
      }
    }

    return null;
  }

  Future<void> _refreshTokenStatus() async {
    try {
      final secure = ref.read(flutterSecureStorageProvider);
      final token = await secure.read(key: StorageKeys.smartHomeHaToken);
      state = state.copyWith(
        hasHaToken: token != null && token.trim().isNotEmpty,
      );
    } catch (_) {
      // Ignore secure storage unavailable in unit tests.
    }
  }

  Future<void> saveHomeAssistantConfig({
    required String baseUrl,
    String? bearerToken,
  }) async {
    final cleanUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(StorageKeys.smartHomeHaBaseUrl, cleanUrl);

    var hasToken = state.hasHaToken;
    if (bearerToken != null && bearerToken.trim().isNotEmpty) {
      final secure = ref.read(flutterSecureStorageProvider);
      await secure.write(
        key: StorageKeys.smartHomeHaToken,
        value: bearerToken.trim(),
      );
      hasToken = true;
    }

    state = state.copyWith(
      haBaseUrl: cleanUrl,
      hasHaToken: hasToken,
      statusMessage: 'Saved Home Assistant configuration.',
    );
  }

  Future<void> clearHomeAssistantToken() async {
    try {
      await ref
          .read(flutterSecureStorageProvider)
          .delete(key: StorageKeys.smartHomeHaToken);
    } catch (_) {}
    state = state.copyWith(
      hasHaToken: false,
      statusMessage: 'Cleared Home Assistant token.',
    );
  }

  Future<void> addDevice({
    required String name,
    required String room,
    required SmartHomeBackend backend,
    String entityId = '',
    String onWebhookUrl = '',
    String offWebhookUrl = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final device = SmartHomeDevice(
      id: 'sh_${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      room: room.trim().isEmpty ? 'Home' : room.trim(),
      backend: backend,
      entityId: entityId.trim(),
      onWebhookUrl: onWebhookUrl.trim(),
      offWebhookUrl: offWebhookUrl.trim(),
    );

    final updated = <SmartHomeDevice>[...state.devices, device];
    await _persistDevices(updated);
    state = state.copyWith(
      devices: updated,
      statusMessage: 'Added "${device.name}".',
    );
  }

  Future<void> deleteDevice(String id) async {
    final updated = state.devices
        .where((d) => d.id != id)
        .toList(growable: false);
    await _persistDevices(updated);
    state = state.copyWith(devices: updated, statusMessage: 'Device removed.');
  }

  /// Finds a configured device matching [query] by name or room + name.
  SmartHomeDevice? matchDevice(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    for (final d in state.devices) {
      final name = d.name.toLowerCase();
      final combined = '${d.room} ${d.name}'.toLowerCase();
      if (name == q || combined == q || name.contains(q) || q.contains(name)) {
        return d;
      }
    }
    return null;
  }

  /// Toggles or sets [device] to [turnOn] using its configured backend.
  Future<String> setDevicePower(
    SmartHomeDevice device, {
    required bool turnOn,
  }) async {
    state = state.copyWith(isBusy: true, clearStatus: true);
    try {
      final client = ref.read(smartHomeHttpClientProvider);
      if (device.backend == SmartHomeBackend.homeAssistant) {
        if (state.haBaseUrl.isEmpty) {
          const msg =
              'Configure your Home Assistant local URL in Smart Home first.';
          state = state.copyWith(isBusy: false, statusMessage: msg);
          return msg;
        }
        final token =
            await ref
                .read(flutterSecureStorageProvider)
                .read(key: StorageKeys.smartHomeHaToken) ??
            '';
        if (token.trim().isEmpty) {
          const msg =
              'Add your Home Assistant Long-Lived Access Token in Smart Home first.';
          state = state.copyWith(isBusy: false, statusMessage: msg);
          return msg;
        }

        final entity = device.entityId.trim();
        final domain = entity.contains('.')
            ? entity.split('.').first
            : 'homeassistant';
        final service = domain == 'scene'
            ? 'turn_on'
            : (turnOn ? 'turn_on' : 'turn_off');
        final uri = Uri.parse(
          '${state.haBaseUrl}/api/services/$domain/$service',
        );

        final response = await client
            .post(
              uri,
              headers: <String, String>{
                'Authorization': 'Bearer ${token.trim()}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, String>{'entity_id': entity}),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final msg =
              'Home Assistant returned HTTP ${response.statusCode} for ${device.name}.';
          state = state.copyWith(isBusy: false, statusMessage: msg);
          return msg;
        }
      } else {
        final targetUrl = turnOn
            ? device.onWebhookUrl
            : (device.offWebhookUrl.isNotEmpty
                  ? device.offWebhookUrl
                  : device.onWebhookUrl);
        if (targetUrl.isEmpty) {
          final msg = 'No webhook URL configured for ${device.name}.';
          state = state.copyWith(isBusy: false, statusMessage: msg);
          return msg;
        }
        final response = await client
            .post(Uri.parse(targetUrl))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final msg =
              'Webhook returned HTTP ${response.statusCode} for ${device.name}.';
          state = state.copyWith(isBusy: false, statusMessage: msg);
          return msg;
        }
      }

      final updated = state.devices
          .map((d) => d.id == device.id ? d.copyWith(isOn: turnOn) : d)
          .toList(growable: false);
      await _persistDevices(updated);
      final msg = 'Turned ${turnOn ? 'ON' : 'OFF'} ${device.name}.';
      state = state.copyWith(
        devices: updated,
        isBusy: false,
        statusMessage: msg,
      );
      return msg;
    } catch (error) {
      final msg = 'Smart Home request failed for ${device.name}: $error';
      state = state.copyWith(isBusy: false, statusMessage: msg);
      return msg;
    }
  }

  Future<void> _persistDevices(List<SmartHomeDevice> devices) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final encoded = jsonEncode(devices.map((d) => d.toJson()).toList());
    await prefs.setString(StorageKeys.smartHomeDevices, encoded);
  }
}

final smartHomeControllerProvider =
    NotifierProvider<SmartHomeController, SmartHomeState>(
      SmartHomeController.new,
    );
