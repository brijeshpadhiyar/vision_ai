import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/intelligence/command_normalizer.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/intelligence/entity_extractor.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/automation_routine.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/automation/presentation/controllers/routines_controller.dart';
import 'package:vision_ai/features/automation/presentation/controllers/trusted_commands_controller.dart';
import 'package:vision_ai/features/contacts/data/repositories/contact_alias_repository.dart';
import 'package:vision_ai/features/contacts/domain/entities/contact_resolution.dart';
import 'package:vision_ai/features/contacts/domain/services/contact_resolver.dart';
import 'package:vision_ai/features/notifications/domain/services/notification_digest_service.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Immutable presentation state for Phase 4 Android device automation.
@immutable
class AutomationState {
  const AutomationState({
    this.isExecuting = false,
    this.hasCallPermission = false,
    this.hasContactsPermission = false,
    this.flashlightOn = false,
    this.deviceStatus,
    this.installedApps = const <InstalledAppInfo>[],
    this.pendingConfirmation,
    this.contactChoices = const <ContactMatch>[],
    this.contactSearchResults = const <ContactMatch>[],
    this.recentActions = const <AutomationExecutionEntry>[],
    this.lastResult,
    this.errorMessage,
    this.suggestedContact,
    this.spokenContactQuery,
    this.suggestSaveAlias = false,
    this.lastSelectedContactId,
  });

  final bool isExecuting;
  final bool hasCallPermission;
  final bool hasContactsPermission;
  final bool flashlightOn;
  final DeviceStatusSnapshot? deviceStatus;
  final List<InstalledAppInfo> installedApps;
  final DeviceActionRequest? pendingConfirmation;
  final List<ContactMatch> contactChoices;
  final List<ContactMatch> contactSearchResults;
  final List<AutomationExecutionEntry> recentActions;
  final DeviceActionResult? lastResult;
  final String? errorMessage;
  final ContactMatch? suggestedContact;
  final String? spokenContactQuery;
  final bool suggestSaveAlias;
  final String? lastSelectedContactId;

  AutomationState copyWith({
    bool? isExecuting,
    bool? hasCallPermission,
    bool? hasContactsPermission,
    bool? flashlightOn,
    DeviceStatusSnapshot? deviceStatus,
    List<InstalledAppInfo>? installedApps,
    DeviceActionRequest? pendingConfirmation,
    bool clearPending = false,
    List<ContactMatch>? contactChoices,
    List<ContactMatch>? contactSearchResults,
    List<AutomationExecutionEntry>? recentActions,
    DeviceActionResult? lastResult,
    String? errorMessage,
    bool clearError = false,
    ContactMatch? suggestedContact,
    String? spokenContactQuery,
    bool? suggestSaveAlias,
    String? lastSelectedContactId,
  }) {
    return AutomationState(
      isExecuting: isExecuting ?? this.isExecuting,
      hasCallPermission: hasCallPermission ?? this.hasCallPermission,
      hasContactsPermission:
          hasContactsPermission ?? this.hasContactsPermission,
      flashlightOn: flashlightOn ?? this.flashlightOn,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      installedApps: installedApps ?? this.installedApps,
      pendingConfirmation: clearPending
          ? null
          : (pendingConfirmation ?? this.pendingConfirmation),
      contactChoices: contactChoices ?? this.contactChoices,
      contactSearchResults: contactSearchResults ?? this.contactSearchResults,
      recentActions: recentActions ?? this.recentActions,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      suggestedContact: clearPending
          ? null
          : (suggestedContact ?? this.suggestedContact),
      spokenContactQuery: clearPending
          ? null
          : (spokenContactQuery ?? this.spokenContactQuery),
      suggestSaveAlias: clearPending
          ? false
          : (suggestSaveAlias ?? this.suggestSaveAlias),
      lastSelectedContactId:
          lastSelectedContactId ?? this.lastSelectedContactId,
    );
  }
}

/// Global Riverpod provider for the [AutomationController].
final automationControllerProvider =
    NotifierProvider<AutomationController, AutomationState>(
      AutomationController.new,
    );

/// Orchestrates permission-guarded Android system intents, contacts, calls,
/// alarms, timers, app launching, and contextual device status.
class AutomationController extends Notifier<AutomationState> {
  static const int _maxHistoryEntries = 50;

  @override
  AutomationState build() {
    ref.watch(deviceAutomationRepositoryProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedHistory = _decodeHistory(
      prefs.getString(StorageKeys.automationExecutionHistory),
    );
    return AutomationState(recentActions: savedHistory);
  }

  /// Clears persisted and in-memory automation execution history.
  Future<void> clearExecutionHistory() async {
    state = state.copyWith(recentActions: const <AutomationExecutionEntry>[]);
    await ref
        .read(sharedPreferencesProvider)
        .remove(StorageKeys.automationExecutionHistory);
  }

  Future<void> _persistHistory(List<AutomationExecutionEntry> history) async {
    final encoded = jsonEncode(
      history.map((e) => e.toJson()).toList(growable: false),
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(StorageKeys.automationExecutionHistory, encoded);
  }

  static List<AutomationExecutionEntry> _decodeHistory(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <AutomationExecutionEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return const <AutomationExecutionEntry>[];
      }
      return List<AutomationExecutionEntry>.unmodifiable(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(AutomationExecutionEntry.fromJson)
            .where((e) => e.id.isNotEmpty)
            .take(_maxHistoryEntries),
      );
    } on FormatException {
      return const <AutomationExecutionEntry>[];
    }
  }

  /// Refreshes runtime Android permission status and live device telemetry.
  Future<void> refreshEnvironment() async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final callGranted = await repo.checkPermission(
      AutomationPermission.callPhone,
    );
    final contactsGranted = await repo.checkPermission(
      AutomationPermission.readContacts,
    );
    final status = await repo.getDeviceStatus();

    state = state.copyWith(
      hasCallPermission: callGranted,
      hasContactsPermission: contactsGranted,
      flashlightOn: status.isFlashlightOn,
      deviceStatus: status,
      clearError: true,
    );
  }

  /// Loads launcher apps installed on the Android device.
  Future<List<InstalledAppInfo>> loadInstalledApps() async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final apps = await repo.getInstalledApps();
    state = state.copyWith(installedApps: apps);
    return apps;
  }

  /// Requests a specific Android runtime permission (`CALL_PHONE` or `READ_CONTACTS`).
  Future<bool> requestPermission(AutomationPermission permission) async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    try {
      final granted = await repo.requestPermission(permission);
      state = state.copyWith(
        hasCallPermission: permission == AutomationPermission.callPhone
            ? granted
            : state.hasCallPermission,
        hasContactsPermission: permission == AutomationPermission.readContacts
            ? granted
            : state.hasContactsPermission,
        clearError: granted,
        errorMessage: granted
            ? null
            : '${permission.displayName} permission was denied.',
      );
      return granted;
    } on AppException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return false;
    }
  }

  /// Attempts to parse and execute a direct natural-language device command
  /// or a matching user-defined [AutomationRoutine].
  ///
  /// Returns `null` if [input] is not a recognized direct device command or routine.
  Future<DeviceActionResult?> tryHandleNaturalCommand(String input) async {
    final settings = ref.read(settingsControllerProvider);
    if (!settings.deviceActionsEnabled) {
      return null;
    }
    final matchingRoutine = ref
        .read(routinesControllerProvider.notifier)
        .findByVoiceTrigger(input);
    if (matchingRoutine != null) {
      return executeRoutine(matchingRoutine);
    }
    final parsed = DeviceIntentParser.parseLocalCommand(input);
    if (parsed == null) {
      return null;
    }
    return executeRequest(parsed);
  }

  /// Executes a user-defined [AutomationRoutine] step-by-step, preserving
  /// confirmation gates for any sensitive steps unless the routine is trusted.
  Future<DeviceActionResult> executeRoutine(
    AutomationRoutine routine, {
    bool confirmed = false,
  }) async {
    final parsedSteps = <DeviceActionRequest>[];
    for (final stepText in routine.commandSteps) {
      final parsed = DeviceIntentParser.parseLocalCommand(stepText);
      if (parsed != null) {
        parsedSteps.add(parsed);
      }
    }
    if (parsedSteps.isEmpty) {
      return DeviceActionResult(
        success: false,
        status: DeviceActionStatus.failed,
        actionType: DeviceActionType.deviceStatus,
        summary: 'Routine "${routine.name}" has no executable device steps.',
      );
    }
    final primary = parsedSteps.first;
    final chained = DeviceActionRequest(
      type: primary.type,
      displaySummary: 'Routine: ${routine.name}',
      target: primary.target,
      hour: primary.hour,
      minute: primary.minute,
      durationSeconds: primary.durationSeconds,
      label: primary.label,
      message: primary.message,
      enabled: primary.enabled,
      requiresConfirmation:
          !routine.trusted && parsedSteps.any((s) => s.requiresConfirmation),
      contactOrdinalIndex: primary.contactOrdinalIndex,
      isTomorrow: primary.isTomorrow,
      followUpActions: parsedSteps.skip(1).toList(growable: false),
    );
    return executeRequest(chained, confirmed: confirmed || routine.trusted);
  }

  /// Executes a structured [DeviceActionRequest] (including multi-step chains)
  /// with permission guards, lifecycle tracking, and latency telemetry.
  Future<DeviceActionResult> executeRequest(
    DeviceActionRequest request, {
    bool confirmed = false,
    List<String> alternativeQueries = const <String>[],
  }) async {
    final logger = ref.read(appLoggerProvider);
    final telemetry = ref.read(telemetryProvider.notifier);
    final stopwatch = Stopwatch()..start();

    state = state.copyWith(
      isExecuting: true,
      clearError: true,
      contactChoices: const <ContactMatch>[],
      contactSearchResults: const <ContactMatch>[],
    );

    try {
      var result = await _dispatchRequest(
        request,
        confirmed: confirmed,
        alternativeQueries: alternativeQueries,
      );

      // Execute any chained follow-up steps sequentially if the primary step succeeded.
      if (result.success && request.followUpActions.isNotEmpty) {
        final stepSummaries = <String>['Step 1: ${result.summary}'];
        for (var i = 0; i < request.followUpActions.length; i++) {
          final followUp = request.followUpActions[i];
          final stepResult = await _dispatchRequest(
            followUp,
            confirmed: confirmed,
            alternativeQueries: alternativeQueries,
          );
          if (!stepResult.success) {
            if (stepResult.status == DeviceActionStatus.confirmationRequired ||
                stepResult.status == DeviceActionStatus.ambiguousContact) {
              // Preserve remaining follow-up steps on pendingConfirmation
              final remaining = request.followUpActions
                  .skip(i + 1)
                  .toList(growable: false);
              if (state.pendingConfirmation != null && remaining.isNotEmpty) {
                final curPending = state.pendingConfirmation!;
                state = state.copyWith(
                  pendingConfirmation: DeviceActionRequest(
                    type: curPending.type,
                    displaySummary: curPending.displaySummary,
                    target: curPending.target,
                    hour: curPending.hour,
                    minute: curPending.minute,
                    durationSeconds: curPending.durationSeconds,
                    label: curPending.label,
                    message: curPending.message,
                    enabled: curPending.enabled,
                    requiresConfirmation: curPending.requiresConfirmation,
                    contactOrdinalIndex: curPending.contactOrdinalIndex,
                    isTomorrow: curPending.isTomorrow,
                    followUpActions: remaining,
                  ),
                );
              }
              stepSummaries.add('Step ${i + 2}: ${stepResult.summary}');
            } else {
              stepSummaries.add('Step ${i + 2} failed: ${stepResult.summary}');
            }
            result = DeviceActionResult(
              success: false,
              status: stepResult.status,
              actionType: followUp.type,
              summary: stepSummaries.join(' | '),
              details: stepResult.details,
              requiresPermission: stepResult.requiresPermission,
              missingPermission: stepResult.missingPermission,
              contacts: stepResult.contacts,
              notifications: stepResult.notifications,
              deviceStatus: stepResult.deviceStatus,
              suggestedContact: stepResult.suggestedContact,
              spokenContactQuery: stepResult.spokenContactQuery,
              contactConfidence: stepResult.contactConfidence,
            );
            break;
          }
          stepSummaries.add('Step ${i + 2}: ${stepResult.summary}');
          result = DeviceActionResult(
            success: true,
            status: stepResult.status,
            actionType: followUp.type,
            summary: stepSummaries.join(' | '),
            details: stepResult.details,
            contacts: stepResult.contacts,
            notifications: stepResult.notifications,
            deviceStatus: stepResult.deviceStatus,
          );
        }
      }

      stopwatch.stop();
      telemetry.recordAutomationExecution(
        request.type,
        stopwatch.elapsedMilliseconds,
        success: result.success,
      );

      final entry = AutomationExecutionEntry(
        id: 'act_${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        request: request,
        result: result,
      );
      final updatedHistory = <AutomationExecutionEntry>[
        entry,
        ...state.recentActions,
      ].take(_maxHistoryEntries).toList(growable: false);

      state = state.copyWith(
        isExecuting: false,
        lastResult: result,
        recentActions: updatedHistory,
        errorMessage: result.success ? null : result.summary,
        clearPending: result.success || confirmed,
      );
      await _persistHistory(updatedHistory);

      logger.info('Device action [${request.type.wireId}]: ${result.summary}');
      return result;
    } on DeviceAutomationException catch (error) {
      stopwatch.stop();
      telemetry.recordAutomationExecution(
        request.type,
        stopwatch.elapsedMilliseconds,
        success: false,
      );
      telemetry.recordSanitizedError(
        'Automation[${request.type.wireId}]',
        error,
      );

      final result = DeviceActionResult(
        success: false,
        actionType: request.type,
        summary: error.message,
      );
      state = state.copyWith(
        isExecuting: false,
        lastResult: result,
        errorMessage: error.message,
      );
      return result;
    }
  }

  Future<DeviceActionResult> _dispatchRequest(
    DeviceActionRequest request, {
    required bool confirmed,
    List<String> alternativeQueries = const <String>[],
  }) async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final settings = ref.read(settingsControllerProvider);

    switch (request.type) {
      case DeviceActionType.callPhone:
        return _handlePhoneCallRequest(
          request,
          directCallEnabled: settings.directPhoneCallsEnabled,
          confirmed: confirmed,
          alternativeQueries: alternativeQueries,
        );

      case DeviceActionType.lookupContacts:
        final hasContacts = await _ensurePermission(
          AutomationPermission.readContacts,
        );
        if (!hasContacts) {
          return const DeviceActionResult(
            success: false,
            actionType: DeviceActionType.lookupContacts,
            summary: 'Contacts permission is required to search contacts.',
            requiresPermission: true,
            missingPermission: AutomationPermission.readContacts,
          );
        }
        final altContactQueries = _extractAlternativeContactQueries(
          alternativeQueries,
        );
        final resolution = await ref
            .read(contactResolverProvider)
            .resolve(
              primaryQuery: request.target,
              alternativeQueries: altContactQueries,
              ordinalIndex: request.contactOrdinalIndex,
              recentSelectedContactId: state.lastSelectedContactId,
            );
        final matches = resolution.candidates
            .map((c) => c.contact)
            .toList(growable: false);
        state = state.copyWith(contactSearchResults: matches);
        return DeviceActionResult(
          success: matches.isNotEmpty,
          actionType: DeviceActionType.lookupContacts,
          summary: matches.isEmpty
              ? resolution.promptMessage
              : 'Found ${matches.length} contact(s) matching "${request.target}".',
          contacts: matches,
          suggestedContact: resolution.bestCandidate?.contact,
          contactConfidence: resolution.bestCandidate?.score,
        );

      case DeviceActionType.setAlarm:
        return repo.setAlarm(
          hour: request.hour ?? 7,
          minute: request.minute ?? 0,
          label: request.label,
          isTomorrow: request.isTomorrow,
        );

      case DeviceActionType.setTimer:
        return repo.setTimer(
          seconds: request.durationSeconds ?? 60,
          label: request.label,
        );

      case DeviceActionType.launchApp:
        return repo.launchApp(request.target);

      case DeviceActionType.openSettings:
        return repo.openSystemSettings(
          request.target.isEmpty ? 'main' : request.target,
        );

      case DeviceActionType.sendSms:
        if (!confirmed &&
            !ref
                .read(trustedCommandsControllerProvider)
                .isActionTrusted(DeviceActionType.sendSms)) {
          state = state.copyWith(pendingConfirmation: request);
          return DeviceActionResult(
            success: false,
            status: DeviceActionStatus.confirmationRequired,
            actionType: DeviceActionType.sendSms,
            summary: 'Confirm before composing SMS to ${request.target}.',
          );
        }
        return _handleSmsRequest(
          request,
          alternativeQueries: alternativeQueries,
        );

      case DeviceActionType.sendWhatsapp:
        if (!confirmed &&
            !ref
                .read(trustedCommandsControllerProvider)
                .isActionTrusted(DeviceActionType.sendWhatsapp)) {
          state = state.copyWith(pendingConfirmation: request);
          return DeviceActionResult(
            success: false,
            status: DeviceActionStatus.confirmationRequired,
            actionType: DeviceActionType.sendWhatsapp,
            summary: 'Confirm before opening WhatsApp for ${request.target}.',
          );
        }
        return _handleWhatsAppRequest(
          request,
          alternativeQueries: alternativeQueries,
        );

      case DeviceActionType.readNotifications:
        return _handleReadNotificationsRequest(settings);

      case DeviceActionType.openUrl:
        if (!confirmed &&
            !ref
                .read(trustedCommandsControllerProvider)
                .isActionTrusted(DeviceActionType.openUrl)) {
          state = state.copyWith(pendingConfirmation: request);
          return DeviceActionResult(
            success: false,
            status: DeviceActionStatus.confirmationRequired,
            actionType: DeviceActionType.openUrl,
            summary: 'Confirm before opening URL: ${request.target}.',
          );
        }
        return repo.openUrl(request.target);

      case DeviceActionType.toggleFlashlight:
        final enabled = request.enabled ?? !state.flashlightOn;
        final res = await repo.setFlashlight(enabled: enabled);
        if (res.success) {
          state = state.copyWith(flashlightOn: enabled);
        }
        return res;

      case DeviceActionType.setRingerMode:
        final mode = request.target.isEmpty ? 'normal' : request.target;
        final res = await repo.setRingerMode(mode);
        if (res.success) {
          final status = await repo.getDeviceStatus();
          state = state.copyWith(deviceStatus: status);
        }
        return res;

      case DeviceActionType.adjustVolume:
        return repo.adjustVolume(
          request.target.isEmpty ? 'up' : request.target,
        );

      case DeviceActionType.webSearch:
        return repo.webSearch(request.target);

      case DeviceActionType.navigateTo:
        return repo.navigateTo(request.target);

      case DeviceActionType.deviceStatus:
        final snapshot = await repo.getDeviceStatus();
        state = state.copyWith(
          deviceStatus: snapshot,
          flashlightOn: snapshot.isFlashlightOn,
        );
        return DeviceActionResult(
          success: true,
          actionType: DeviceActionType.deviceStatus,
          summary: snapshot.toReadableSummary(),
          deviceStatus: snapshot,
        );

      case DeviceActionType.dismissAlarm:
        return repo.dismissAlarm();

      case DeviceActionType.dismissTimer:
        return repo.dismissTimer();

      case DeviceActionType.stopSpeaking:
        return const DeviceActionResult(
          success: true,
          actionType: DeviceActionType.stopSpeaking,
          summary: 'Stopped speech playback.',
        );

      case DeviceActionType.repeatLast:
        return const DeviceActionResult(
          success: true,
          actionType: DeviceActionType.repeatLast,
          summary: 'Repeating previous response.',
        );

      case DeviceActionType.cancelAction:
        cancelPendingAction();
        return const DeviceActionResult(
          success: true,
          status: DeviceActionStatus.cancelled,
          actionType: DeviceActionType.cancelAction,
          summary: 'Cancelled pending action.',
        );
    }
  }

  Future<DeviceActionResult> _handlePhoneCallRequest(
    DeviceActionRequest request, {
    required bool directCallEnabled,
    required bool confirmed,
    List<String> alternativeQueries = const <String>[],
  }) async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final rawTarget = request.target.trim();
    var phoneNumber = rawTarget;
    var resolvedLabel = rawTarget;

    if (!_looksLikePhoneNumber(rawTarget)) {
      final hasContacts = await _ensurePermission(
        AutomationPermission.readContacts,
      );
      if (!hasContacts) {
        return const DeviceActionResult(
          success: false,
          actionType: DeviceActionType.callPhone,
          summary: 'Contacts permission is required to call a contact by name.',
          requiresPermission: true,
          missingPermission: AutomationPermission.readContacts,
        );
      }

      final resolution = await _resolveContactForAction(
        request,
        actionType: DeviceActionType.callPhone,
        alternativeQueries: alternativeQueries,
      );
      if (resolution.earlyResult != null) {
        return resolution.earlyResult!;
      }

      final selectedMatch = resolution.contact!;
      phoneNumber = selectedMatch.phoneNumber;
      resolvedLabel = '${selectedMatch.name} ($phoneNumber)';
      if (selectedMatch.contactId.isNotEmpty) {
        state = state.copyWith(lastSelectedContactId: selectedMatch.contactId);
      }
    }

    if (directCallEnabled) {
      final hasCall = await _ensurePermission(AutomationPermission.callPhone);
      if (!hasCall) {
        // Safe fallback to dialer when CALL_PHONE is denied.
        return repo.makePhoneCall(phoneNumber: phoneNumber, directCall: false);
      }
      if (!confirmed) {
        final pending = DeviceActionRequest(
          type: DeviceActionType.callPhone,
          target: phoneNumber,
          displaySummary: 'Place direct call to $resolvedLabel',
          requiresConfirmation: true,
          followUpActions: request.followUpActions,
        );
        state = state.copyWith(pendingConfirmation: pending);
        return DeviceActionResult(
          success: false,
          status: DeviceActionStatus.confirmationRequired,
          actionType: DeviceActionType.callPhone,
          summary: 'Confirm direct call to $resolvedLabel.',
        );
      }
    }

    return repo.makePhoneCall(
      phoneNumber: phoneNumber,
      directCall: directCallEnabled && confirmed,
    );
  }

  Future<DeviceActionResult> _handleSmsRequest(
    DeviceActionRequest request, {
    List<String> alternativeQueries = const <String>[],
  }) async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final rawTarget = request.target.trim();

    if (_looksLikePhoneNumber(rawTarget)) {
      return repo.sendSms(phoneNumber: rawTarget, message: request.message);
    }

    final hasContacts = await _ensurePermission(
      AutomationPermission.readContacts,
    );
    if (!hasContacts) {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.sendSms,
        summary:
            'Contacts permission is required to message a contact by name.',
        requiresPermission: true,
        missingPermission: AutomationPermission.readContacts,
      );
    }

    final resolution = await _resolveContactForAction(
      request,
      actionType: DeviceActionType.sendSms,
      alternativeQueries: alternativeQueries,
    );
    if (resolution.earlyResult != null) {
      return resolution.earlyResult!;
    }

    return repo.sendSms(
      phoneNumber: resolution.contact!.phoneNumber,
      message: request.message,
    );
  }

  Future<DeviceActionResult> _handleWhatsAppRequest(
    DeviceActionRequest request, {
    List<String> alternativeQueries = const <String>[],
  }) async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final rawTarget = request.target.trim();
    if (rawTarget.isEmpty) {
      return repo.sendWhatsApp(message: request.message);
    }

    if (_looksLikePhoneNumber(rawTarget)) {
      return repo.sendWhatsApp(
        phoneNumber: rawTarget,
        message: request.message,
      );
    }

    final hasContacts = await _ensurePermission(
      AutomationPermission.readContacts,
    );
    if (!hasContacts) {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.permissionRequired,
        actionType: DeviceActionType.sendWhatsapp,
        summary: 'Contacts permission is required to look up a recipient for WhatsApp.',
        requiresPermission: true,
        missingPermission: AutomationPermission.readContacts,
      );
    }

    final resolution = await _resolveContactForAction(
      request,
      actionType: DeviceActionType.sendWhatsapp,
      alternativeQueries: alternativeQueries,
    );
    if (resolution.earlyResult != null) {
      return resolution.earlyResult!;
    }

    return repo.sendWhatsApp(
      phoneNumber: resolution.contact!.phoneNumber,
      message: request.message,
    );
  }

  List<String> _extractAlternativeContactQueries(List<String> hypotheses) {
    if (hypotheses.isEmpty) return const <String>[];
    final names = <String>{};
    for (final hyp in hypotheses) {
      final norm = CommandNormalizer.normalize(hyp);
      final extracted = EntityExtractor.extractContact(
        norm,
        const ConversationIntelligenceContext(),
      );
      if (extracted.contact.isNotEmpty) {
        names.add(extracted.contact);
      } else {
        final msgExtracted = EntityExtractor.extractMessageTargets(
          norm,
          const ConversationIntelligenceContext(),
        );
        if (msgExtracted.recipient.isNotEmpty) {
          names.add(msgExtracted.recipient);
        }
      }
    }
    return names.toList(growable: false);
  }

  /// Shared confidence-gated contact resolver enforcing High / Medium ("Did you mean?") /
  /// Low / Ambiguous policies consistently across Call, SMS, and WhatsApp.
  Future<({ContactMatch? contact, DeviceActionResult? earlyResult})>
  _resolveContactForAction(
    DeviceActionRequest request, {
    required DeviceActionType actionType,
    List<String> alternativeQueries = const <String>[],
  }) async {
    final altContactQueries = _extractAlternativeContactQueries(
      alternativeQueries,
    );
    final resolution = await ref
        .read(contactResolverProvider)
        .resolve(
          primaryQuery: request.target,
          alternativeQueries: altContactQueries,
          ordinalIndex: request.contactOrdinalIndex,
          recentSelectedContactId: state.lastSelectedContactId,
        );

    switch (resolution.confidenceBand) {
      case ContactConfidenceBand.high:
        return (contact: resolution.bestCandidate!.contact, earlyResult: null);

      case ContactConfidenceBand.medium:
        final suggested = resolution.bestCandidate!.contact;
        final confirmReq = DeviceActionRequest(
          type: actionType,
          target: suggested.phoneNumber,
          message: request.message,
          displaySummary: switch (actionType) {
            DeviceActionType.sendSms => 'Send SMS to ${suggested.name}?',
            DeviceActionType.sendWhatsapp => 'WhatsApp ${suggested.name}?',
            _ => 'Call ${suggested.name} (${suggested.phoneNumber})?',
          },
          requiresConfirmation: true,
          followUpActions: request.followUpActions,
        );
        state = state.copyWith(
          pendingConfirmation: confirmReq,
          suggestedContact: suggested,
          spokenContactQuery: request.target,
          suggestSaveAlias: resolution.suggestSaveAlias,
          contactChoices: resolution.candidates
              .map((c) => c.contact)
              .toList(growable: false),
        );
        return (
          contact: null,
          earlyResult: DeviceActionResult(
            success: false,
            status: DeviceActionStatus.confirmationRequired,
            actionType: actionType,
            summary: resolution.promptMessage,
            contacts: resolution.candidates
                .map((c) => c.contact)
                .toList(growable: false),
            suggestedContact: suggested,
            spokenContactQuery: request.target,
            contactConfidence: resolution.bestCandidate!.score,
          ),
        );

      case ContactConfidenceBand.ambiguous:
        final choices = resolution.candidates
            .map((c) => c.contact)
            .toList(growable: false);
        state = state.copyWith(
          contactChoices: choices,
          pendingConfirmation: request,
          spokenContactQuery: request.target,
        );
        return (
          contact: null,
          earlyResult: DeviceActionResult(
            success: false,
            status: DeviceActionStatus.ambiguousContact,
            actionType: actionType,
            summary: resolution.promptMessage,
            contacts: choices,
          ),
        );

      case ContactConfidenceBand.low:
        final fallbackChoices = resolution.candidates
            .map((c) => c.contact)
            .toList(growable: false);
        if (fallbackChoices.isNotEmpty) {
          state = state.copyWith(
            contactChoices: fallbackChoices,
            pendingConfirmation: request,
            spokenContactQuery: request.target,
          );
        }
        return (
          contact: null,
          earlyResult: DeviceActionResult(
            success: false,
            actionType: actionType,
            summary: resolution.promptMessage,
            contacts: fallbackChoices,
          ),
        );

      case ContactConfidenceBand.none:
        return (
          contact: null,
          earlyResult: DeviceActionResult(
            success: false,
            actionType: actionType,
            summary: resolution.promptMessage,
          ),
        );
    }
  }

  Future<DeviceActionResult> _handleReadNotificationsRequest(
    AppSettings settings,
  ) async {
    final hasConsent = settings.notificationListenerConsent;
    if (!hasConsent) {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.confirmationRequired,
        actionType: DeviceActionType.readNotifications,
        summary: 'Enable Notification Reader consent in Settings before VISION reads local notifications.',
      );
    }

    final repo = ref.read(deviceAutomationRepositoryProvider);
    final granted = await repo.checkPermission(
      AutomationPermission.notifications,
    );
    if (!granted) {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.permissionRequired,
        actionType: DeviceActionType.readNotifications,
        summary: 'Android Notification Access is required to read recent notifications.',
        requiresPermission: true,
        missingPermission: AutomationPermission.notifications,
      );
    }

    final blockedPackages = ref
        .read(trustedCommandsControllerProvider)
        .blockedNotificationPackages;
    final rawItems = await repo.getRecentNotifications(limit: 15);
    final items = rawItems
        .where((n) => !blockedPackages.contains(n.packageName))
        .toList(growable: false);
    if (items.isEmpty) {
      return const DeviceActionResult(
        success: true,
        status: DeviceActionStatus.success,
        actionType: DeviceActionType.readNotifications,
        summary: 'No recent notifications captured.',
      );
    }
    final digest = await ref
        .read(notificationDigestServiceProvider)
        .generateDigest(notifications: items, settings: settings);
    return DeviceActionResult(
      success: true,
      status: DeviceActionStatus.success,
      actionType: DeviceActionType.readNotifications,
      summary: digest.spokenSummary,
      notifications: items,
    );
  }

  Future<bool> _ensurePermission(AutomationPermission permission) async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    var granted = await repo.checkPermission(permission);
    if (!granted) {
      granted = await repo.requestPermission(permission);
    }
    state = state.copyWith(
      hasCallPermission: permission == AutomationPermission.callPhone
          ? granted
          : state.hasCallPermission,
      hasContactsPermission: permission == AutomationPermission.readContacts
          ? granted
          : state.hasContactsPermission,
    );
    return granted;
  }

  /// Confirms and executes the currently queued [AutomationState.pendingConfirmation],
  /// optionally persisting a user-confirmed voice alias when [saveAsAlias] is true
  /// or trusting the command category when [trustFuture] is true.
  Future<DeviceActionResult?> confirmPendingAction({
    bool saveAsAlias = false,
    bool trustFuture = false,
  }) async {
    final pending = state.pendingConfirmation;
    if (pending == null) return null;
    if (trustFuture) {
      await ref
          .read(trustedCommandsControllerProvider.notifier)
          .trustAction(pending.type);
    }
    if (saveAsAlias &&
        state.suggestedContact != null &&
        state.spokenContactQuery != null) {
      await ref
          .read(contactAliasRepositoryProvider)
          .saveConfirmedAlias(
            spokenPhrase: state.spokenContactQuery!,
            contact: state.suggestedContact!,
          );
    }
    state = state.copyWith(
      clearPending: true,
      lastSelectedContactId:
          state.suggestedContact?.contactId ?? state.lastSelectedContactId,
    );
    return executeRequest(pending, confirmed: true);
  }

  /// Selects a contact from [AutomationState.contactChoices] to complete a call/SMS,
  /// optionally saving the spoken query as a personal voice alias.
  Future<DeviceActionResult> selectContactForPendingAction(
    ContactMatch contact, {
    bool saveAsAlias = false,
  }) async {
    final pending = state.pendingConfirmation;
    if (saveAsAlias && state.spokenContactQuery != null) {
      await ref
          .read(contactAliasRepositoryProvider)
          .saveConfirmedAlias(
            spokenPhrase: state.spokenContactQuery!,
            contact: contact,
          );
    }
    final actionType = pending?.type ?? DeviceActionType.callPhone;
    final updatedRequest = DeviceActionRequest(
      type: actionType,
      target: contact.phoneNumber,
      message: pending?.message,
      displaySummary: switch (actionType) {
        DeviceActionType.sendSms => 'Compose SMS to ${contact.name}',
        DeviceActionType.sendWhatsapp => 'Compose WhatsApp to ${contact.name}',
        _ => 'Call ${contact.name} (${contact.phoneNumber})',
      },
      requiresConfirmation: false,
      followUpActions:
          pending?.followUpActions ?? const <DeviceActionRequest>[],
    );
    state = state.copyWith(
      clearPending: true,
      contactChoices: const <ContactMatch>[],
      lastSelectedContactId: contact.contactId.isNotEmpty
          ? contact.contactId
          : state.lastSelectedContactId,
    );
    return executeRequest(updatedRequest, confirmed: true);
  }

  /// Cancels any queued confirmation, contact disambiguation, or contact results.
  void cancelPendingAction() {
    state = state.copyWith(
      clearPending: true,
      contactChoices: const <ContactMatch>[],
      contactSearchResults: const <ContactMatch>[],
    );
  }

  /// Clears contact search results displayed in the UI.
  void clearContactSearchResults() {
    state = state.copyWith(contactSearchResults: const <ContactMatch>[]);
  }

  /// Dismisses any visible automation error banner.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  static bool _looksLikePhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^[+*#0-9]{3,}$').hasMatch(cleaned) &&
        RegExp(r'\d').hasMatch(cleaned);
  }
}
