import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
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
  static const int _maxHistoryEntries = 15;

  @override
  AutomationState build() {
    ref.watch(deviceAutomationRepositoryProvider);
    return const AutomationState();
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

  /// Attempts to parse and execute a direct natural-language device command.
  ///
  /// Returns `null` if [input] is not a recognized direct device command.
  Future<DeviceActionResult?> tryHandleNaturalCommand(String input) async {
    final settings = ref.read(settingsControllerProvider);
    if (!settings.deviceActionsEnabled) {
      return null;
    }
    final parsed = DeviceIntentParser.parseLocalCommand(input);
    if (parsed == null) {
      return null;
    }
    return executeRequest(parsed);
  }

  /// Executes a structured [DeviceActionRequest] (including multi-step chains)
  /// with permission guards, lifecycle tracking, and latency telemetry.
  Future<DeviceActionResult> executeRequest(
    DeviceActionRequest request, {
    bool confirmed = false,
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
      var result = await _dispatchRequest(request, confirmed: confirmed);

      // Execute any chained follow-up steps sequentially if the primary step succeeded.
      if (result.success && request.followUpActions.isNotEmpty) {
        final stepSummaries = <String>['Step 1: ${result.summary}'];
        for (var i = 0; i < request.followUpActions.length; i++) {
          final followUp = request.followUpActions[i];
          final stepResult = await _dispatchRequest(
            followUp,
            confirmed: confirmed,
          );
          if (!stepResult.success) {
            stepSummaries.add('Step ${i + 2} failed: ${stepResult.summary}');
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
  }) async {
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final settings = ref.read(settingsControllerProvider);

    switch (request.type) {
      case DeviceActionType.callPhone:
        return _handlePhoneCallRequest(
          request,
          directCallEnabled: settings.directPhoneCallsEnabled,
          confirmed: confirmed,
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
        final matches = await repo.lookupContacts(request.target);
        state = state.copyWith(contactSearchResults: matches);
        return DeviceActionResult(
          success: matches.isNotEmpty,
          actionType: DeviceActionType.lookupContacts,
          summary: matches.isEmpty
              ? 'No contacts found matching "${request.target}".'
              : 'Found ${matches.length} contact(s) matching "${request.target}".',
          contacts: matches,
        );

      case DeviceActionType.setAlarm:
        return repo.setAlarm(
          hour: request.hour ?? 7,
          minute: request.minute ?? 0,
          label: request.label,
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
        return _handleSmsRequest(request);

      case DeviceActionType.sendWhatsapp:
        return _handleWhatsAppRequest(request);

      case DeviceActionType.readNotifications:
        return _handleReadNotificationsRequest(settings);

      case DeviceActionType.openUrl:
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

      final matches = await repo.lookupContacts(rawTarget);
      if (matches.isEmpty) {
        return DeviceActionResult(
          success: false,
          actionType: DeviceActionType.callPhone,
          summary: 'No contact found matching "$rawTarget".',
        );
      }

      ContactMatch selectedMatch;
      if (matches.length > 1) {
        final ordinal = request.contactOrdinalIndex;
        if (ordinal != null && ordinal >= 0 && ordinal < matches.length) {
          selectedMatch = matches[ordinal];
        } else {
          state = state.copyWith(
            contactChoices: matches,
            pendingConfirmation: request,
          );
          final ordinalOutOfBoundsNote =
              ordinal != null && ordinal >= matches.length
              ? 'Option ${ordinal + 1} was requested, but $rawTarget has ${matches.length} number(s). '
              : '';
          return DeviceActionResult(
            success: false,
            status: DeviceActionStatus.ambiguousContact,
            actionType: DeviceActionType.callPhone,
            summary:
                '${ordinalOutOfBoundsNote}Multiple contacts matched "$rawTarget". Select one to proceed.',
            contacts: matches,
          );
        }
      } else {
        selectedMatch = matches.first;
      }

      phoneNumber = selectedMatch.phoneNumber;
      resolvedLabel = '${selectedMatch.name} ($phoneNumber)';
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
    DeviceActionRequest request,
  ) async {
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

    final matches = await repo.lookupContacts(rawTarget);
    if (matches.isEmpty) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.sendSms,
        summary: 'No contact found matching "$rawTarget".',
      );
    }

    if (matches.length > 1) {
      state = state.copyWith(
        contactChoices: matches,
        pendingConfirmation: request,
      );
      return DeviceActionResult(
        success: false,
        status: DeviceActionStatus.ambiguousContact,
        actionType: DeviceActionType.sendSms,
        summary:
            'Multiple contacts matched "$rawTarget". Choose one to send SMS.',
        contacts: matches,
      );
    }

    return repo.sendSms(
      phoneNumber: matches.first.phoneNumber,
      message: request.message,
    );
  }

  Future<DeviceActionResult> _handleWhatsAppRequest(
    DeviceActionRequest request,
  ) async {
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

    final matches = await repo.lookupContacts(rawTarget);
    if (matches.isEmpty) {
      return DeviceActionResult(
        success: false,
        status: DeviceActionStatus.failed,
        actionType: DeviceActionType.sendWhatsapp,
        summary: 'No contact found matching "$rawTarget".',
      );
    }

    if (matches.length > 1) {
      state = state.copyWith(
        contactChoices: matches,
        pendingConfirmation: request,
      );
      return DeviceActionResult(
        success: false,
        status: DeviceActionStatus.ambiguousContact,
        actionType: DeviceActionType.sendWhatsapp,
        summary:
            'Multiple contacts matched "$rawTarget". Choose one to open WhatsApp.',
        contacts: matches,
      );
    }

    return repo.sendWhatsApp(
      phoneNumber: matches.first.phoneNumber,
      message: request.message,
    );
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

    final items = await repo.getRecentNotifications(limit: 5);
    if (items.isEmpty) {
      return const DeviceActionResult(
        success: true,
        status: DeviceActionStatus.success,
        actionType: DeviceActionType.readNotifications,
        summary: 'No recent notifications captured.',
      );
    }
    final summaryText = items
        .map((n) => '${n.appName}: ${n.title} — ${n.text}'.trim())
        .join(' | ');
    return DeviceActionResult(
      success: true,
      status: DeviceActionStatus.success,
      actionType: DeviceActionType.readNotifications,
      summary: 'Recent notifications (${items.length}): $summaryText',
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

  /// Confirms and executes the currently queued [AutomationState.pendingConfirmation].
  Future<DeviceActionResult?> confirmPendingAction() async {
    final pending = state.pendingConfirmation;
    if (pending == null) return null;
    state = state.copyWith(clearPending: true);
    return executeRequest(pending, confirmed: true);
  }

  /// Selects a contact from [AutomationState.contactChoices] to complete a call/SMS.
  Future<DeviceActionResult> selectContactForPendingAction(
    ContactMatch contact,
  ) async {
    final pending = state.pendingConfirmation;
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
    );
    state = state.copyWith(
      clearPending: true,
      contactChoices: const <ContactMatch>[],
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
