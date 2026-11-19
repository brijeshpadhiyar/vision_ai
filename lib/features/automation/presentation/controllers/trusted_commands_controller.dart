import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/entities/trusted_command_policy.dart';

/// Immutable state holding user-trusted sensitive command categories and
/// blocked notification package names.
@immutable
class TrustedCommandsState {
  const TrustedCommandsState({
    this.trustedSensitiveActions = const <DeviceActionType>{},
    this.blockedNotificationPackages = const <String>{},
  });

  final Set<DeviceActionType> trustedSensitiveActions;
  final Set<String> blockedNotificationPackages;

  /// Returns true if [type] may execute without an extra confirmation prompt.
  bool isActionTrusted(DeviceActionType type) {
    if (!TrustedCommandPolicy.isSensitive(type)) return true;
    return trustedSensitiveActions.contains(type);
  }

  TrustedCommandsState copyWith({
    Set<DeviceActionType>? trustedSensitiveActions,
    Set<String>? blockedNotificationPackages,
  }) {
    return TrustedCommandsState(
      trustedSensitiveActions:
          trustedSensitiveActions ?? this.trustedSensitiveActions,
      blockedNotificationPackages:
          blockedNotificationPackages ?? this.blockedNotificationPackages,
    );
  }
}

/// Manages user-granted trusted command allowlists and notification privacy blocklists.
final trustedCommandsControllerProvider =
    NotifierProvider<TrustedCommandsController, TrustedCommandsState>(
      TrustedCommandsController.new,
    );

class TrustedCommandsController extends Notifier<TrustedCommandsState> {
  @override
  TrustedCommandsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final rawTrusted =
        prefs.getStringList(StorageKeys.trustedSensitiveCommands) ??
        const <String>[];
    final trusted = <DeviceActionType>{};
    for (final wireId in rawTrusted) {
      for (final type in TrustedCommandPolicy.sensitiveActionTypes) {
        if (type.wireId == wireId) {
          trusted.add(type);
        }
      }
    }

    final blocked =
        (prefs.getStringList(StorageKeys.blockedNotificationPackages) ??
                const <String>[])
            .map((pkg) => pkg.trim())
            .where((pkg) => pkg.isNotEmpty)
            .toSet();

    return TrustedCommandsState(
      trustedSensitiveActions: Set<DeviceActionType>.unmodifiable(trusted),
      blockedNotificationPackages: Set<String>.unmodifiable(blocked),
    );
  }

  /// Grants trust to a sensitive [DeviceActionType] so future executions skip confirmation.
  Future<void> trustAction(DeviceActionType type) async {
    if (!TrustedCommandPolicy.isSensitive(type)) return;
    if (state.trustedSensitiveActions.contains(type)) return;
    final next = <DeviceActionType>{...state.trustedSensitiveActions, type};
    state = state.copyWith(
      trustedSensitiveActions: Set<DeviceActionType>.unmodifiable(next),
    );
    await _persistTrusted(next);
  }

  /// Revokes trust from a sensitive [DeviceActionType], restoring confirmation prompts.
  Future<void> revokeAction(DeviceActionType type) async {
    if (!state.trustedSensitiveActions.contains(type)) return;
    final next = <DeviceActionType>{...state.trustedSensitiveActions}
      ..remove(type);
    state = state.copyWith(
      trustedSensitiveActions: Set<DeviceActionType>.unmodifiable(next),
    );
    await _persistTrusted(next);
  }

  /// Revokes all user-trusted sensitive commands.
  Future<void> revokeAll() async {
    if (state.trustedSensitiveActions.isEmpty) return;
    state = state.copyWith(trustedSensitiveActions: const <DeviceActionType>{});
    await ref
        .read(sharedPreferencesProvider)
        .remove(StorageKeys.trustedSensitiveCommands);
  }

  /// Adds a package name to the notification privacy blocklist.
  Future<void> blockNotificationPackage(String packageName) async {
    final trimmed = packageName.trim();
    if (trimmed.isEmpty ||
        state.blockedNotificationPackages.contains(trimmed)) {
      return;
    }
    final next = <String>{...state.blockedNotificationPackages, trimmed};
    state = state.copyWith(
      blockedNotificationPackages: Set<String>.unmodifiable(next),
    );
    await _persistBlockedPackages(next);
  }

  /// Removes a package name from the notification privacy blocklist.
  Future<void> unblockNotificationPackage(String packageName) async {
    final trimmed = packageName.trim();
    if (!state.blockedNotificationPackages.contains(trimmed)) return;
    final next = <String>{...state.blockedNotificationPackages}
      ..remove(trimmed);
    state = state.copyWith(
      blockedNotificationPackages: Set<String>.unmodifiable(next),
    );
    await _persistBlockedPackages(next);
  }

  Future<void> _persistTrusted(Set<DeviceActionType> actions) async {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(
          StorageKeys.trustedSensitiveCommands,
          actions.map((a) => a.wireId).toList(growable: false),
        );
  }

  Future<void> _persistBlockedPackages(Set<String> packages) async {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(
          StorageKeys.blockedNotificationPackages,
          packages.toList(growable: false),
        );
  }
}
