import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/automation_routine.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/routines_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Wave 4 AutomationRoutine persists CRUD, voice trigger matching, and schedule JSON', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const routine = AutomationRoutine(
      id: 'rt_goodnight',
      name: 'Good Night',
      triggerPhrases: <String>['bedtime', 'sleep mode'],
      commandSteps: <String>['turn off flashlight', 'set alarm for 7 am'],
      trusted: true,
      schedule: RoutineSchedule(enabled: true, hour: 23, minute: 0),
    );

    await container
        .read(routinesControllerProvider.notifier)
        .saveRoutine(routine);

    // Reload in a fresh container to verify JSON persistence
    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloaded.dispose);
    final notifier = reloaded.read(routinesControllerProvider.notifier);

    expect(reloaded.read(routinesControllerProvider).length, 1);
    final matched = notifier.findByVoiceTrigger('run bedtime');
    expect(matched, isNotNull);
    expect(matched!.id, 'rt_goodnight');
    expect(matched.schedule?.formattedTime, '23:00');
    expect(matched.trusted, isTrue);

    await notifier.deleteRoutine('rt_goodnight');
    expect(reloaded.read(routinesControllerProvider), isEmpty);
  });

  test('Wave 4 AutomationExecutionEntry round-trips cleanly through JSON', () {
    final entry = AutomationExecutionEntry(
      id: 'exec_1',
      timestamp: DateTime.utc(2026, 11, 19, 10, 30),
      request: const DeviceActionRequest(
        type: DeviceActionType.setAlarm,
        displaySummary: 'Set alarm 07:00',
        target: 'Wake up',
      ),
      result: const DeviceActionResult(
        success: true,
        status: DeviceActionStatus.success,
        actionType: DeviceActionType.setAlarm,
        summary: 'Alarm set for 07:00.',
      ),
    );

    final decoded = AutomationExecutionEntry.fromJson(entry.toJson());
    expect(decoded.id, 'exec_1');
    expect(decoded.request.type, DeviceActionType.setAlarm);
    expect(decoded.result.success, isTrue);
    expect(decoded.result.summary, 'Alarm set for 07:00.');
  });
}
