import 'package:vision_ai/core/intelligence/confidence_manager.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Deterministic execution lifecycle stages for commands routed locally or via AI tools.
enum CommandLifecycleStatus {
  received('Received'),
  understood('Understood'),
  validated('Validated'),
  permissionRequired('Permission Required'),
  confirmationRequired('Confirmation Required'),
  executing('Executing'),
  success('Success'),
  failed('Failed'),
  cancelled('Cancelled');

  const CommandLifecycleStatus(this.label);

  final String label;
}

/// Declarative registration entry for a local-first VISION command.
class CommandDescriptor {
  const CommandDescriptor({
    required this.intentId,
    required this.actionType,
    required this.requiredParameters,
    required this.requiredPermissions,
    required this.timeout,
    required this.requiresConfirmation,
    this.isVoiceControlOnly = false,
  });

  final String intentId;
  final DeviceActionType actionType;
  final List<String> requiredParameters;
  final List<AutomationPermission> requiredPermissions;
  final Duration timeout;
  final bool requiresConfirmation;
  final bool isVoiceControlOnly;

  /// Validates that [request] satisfies parameter requirements before dispatch.
  String? validate(DeviceActionRequest request) =>
      ConfidenceManager.validateRequiredParameters(request);
}

/// Central registry of deterministic local commands executed without cloud AI.
abstract final class CommandRegistry {
  static const Map<DeviceActionType, CommandDescriptor> _byType =
      <DeviceActionType, CommandDescriptor>{
        DeviceActionType.callPhone: CommandDescriptor(
          intentId: 'call_phone',
          actionType: DeviceActionType.callPhone,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[
            AutomationPermission.readContacts,
            AutomationPermission.callPhone,
          ],
          timeout: Duration(seconds: 6),
          requiresConfirmation: true,
        ),
        DeviceActionType.lookupContacts: CommandDescriptor(
          intentId: 'lookup_contacts',
          actionType: DeviceActionType.lookupContacts,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[
            AutomationPermission.readContacts,
          ],
          timeout: Duration(seconds: 5),
          requiresConfirmation: false,
        ),
        DeviceActionType.launchApp: CommandDescriptor(
          intentId: 'launch_app',
          actionType: DeviceActionType.launchApp,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.setAlarm: CommandDescriptor(
          intentId: 'set_alarm',
          actionType: DeviceActionType.setAlarm,
          requiredParameters: <String>['hour'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.setTimer: CommandDescriptor(
          intentId: 'set_timer',
          actionType: DeviceActionType.setTimer,
          requiredParameters: <String>['durationSeconds'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.openSettings: CommandDescriptor(
          intentId: 'open_settings',
          actionType: DeviceActionType.openSettings,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.deviceStatus: CommandDescriptor(
          intentId: 'device_status',
          actionType: DeviceActionType.deviceStatus,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 3),
          requiresConfirmation: false,
        ),
        DeviceActionType.stopSpeaking: CommandDescriptor(
          intentId: 'stop_speaking',
          actionType: DeviceActionType.stopSpeaking,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 1),
          requiresConfirmation: false,
          isVoiceControlOnly: true,
        ),
        DeviceActionType.repeatLast: CommandDescriptor(
          intentId: 'repeat_last',
          actionType: DeviceActionType.repeatLast,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 2),
          requiresConfirmation: false,
          isVoiceControlOnly: true,
        ),
        DeviceActionType.cancelAction: CommandDescriptor(
          intentId: 'cancel_action',
          actionType: DeviceActionType.cancelAction,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 2),
          requiresConfirmation: false,
          isVoiceControlOnly: true,
        ),
        DeviceActionType.dismissAlarm: CommandDescriptor(
          intentId: 'dismiss_alarm',
          actionType: DeviceActionType.dismissAlarm,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.dismissTimer: CommandDescriptor(
          intentId: 'dismiss_timer',
          actionType: DeviceActionType.dismissTimer,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.sendSms: CommandDescriptor(
          intentId: 'send_sms',
          actionType: DeviceActionType.sendSms,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[
            AutomationPermission.readContacts,
          ],
          timeout: Duration(seconds: 6),
          requiresConfirmation: true,
        ),
        DeviceActionType.sendWhatsapp: CommandDescriptor(
          intentId: 'send_whatsapp',
          actionType: DeviceActionType.sendWhatsapp,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 6),
          requiresConfirmation: true,
        ),
        DeviceActionType.readNotifications: CommandDescriptor(
          intentId: 'read_notifications',
          actionType: DeviceActionType.readNotifications,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[
            AutomationPermission.notifications,
          ],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.openUrl: CommandDescriptor(
          intentId: 'open_url',
          actionType: DeviceActionType.openUrl,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 5),
          requiresConfirmation: true,
        ),
        DeviceActionType.toggleFlashlight: CommandDescriptor(
          intentId: 'toggle_flashlight',
          actionType: DeviceActionType.toggleFlashlight,
          requiredParameters: <String>[],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 3),
          requiresConfirmation: false,
        ),
        DeviceActionType.setRingerMode: CommandDescriptor(
          intentId: 'set_ringer_mode',
          actionType: DeviceActionType.setRingerMode,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 3),
          requiresConfirmation: false,
        ),
        DeviceActionType.adjustVolume: CommandDescriptor(
          intentId: 'adjust_volume',
          actionType: DeviceActionType.adjustVolume,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 3),
          requiresConfirmation: false,
        ),
        DeviceActionType.webSearch: CommandDescriptor(
          intentId: 'web_search',
          actionType: DeviceActionType.webSearch,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 4),
          requiresConfirmation: false,
        ),
        DeviceActionType.navigateTo: CommandDescriptor(
          intentId: 'navigate_to',
          actionType: DeviceActionType.navigateTo,
          requiredParameters: <String>['target'],
          requiredPermissions: <AutomationPermission>[],
          timeout: Duration(seconds: 5),
          requiresConfirmation: false,
        ),
      };

  static CommandDescriptor? descriptorFor(DeviceActionType type) =>
      _byType[type];

  static List<CommandDescriptor> get allCommands =>
      List<CommandDescriptor>.unmodifiable(_byType.values);
}
