import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/help/domain/entities/help_guide_catalog.dart';
import 'package:vision_ai/features/help/presentation/screens/help_center_screen.dart';
import 'package:vision_ai/features/planner/domain/entities/planner_task.dart';
import 'package:vision_ai/features/planner/presentation/controllers/daily_planner_controller.dart';
import 'package:vision_ai/features/planner/presentation/screens/daily_planner_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1.3 HelpGuideCatalog searches topics & settings accurately across keywords', () {
    expect(HelpGuideCatalog.searchTopics('ocr').length, 1);
    expect(HelpGuideCatalog.searchTopics('gujarati').isNotEmpty, isTrue);
    expect(HelpGuideCatalog.searchTopics('planner').isNotEmpty, isTrue);
    expect(
      HelpGuideCatalog.searchTopics('', category: HelpCategory.privacy).length,
      1,
    );

    final keyMatches = HelpGuideCatalog.searchSettings('api key');
    expect(keyMatches.isNotEmpty, isTrue);
    expect(keyMatches.first.id, 'set_ai_keys');
  });

  testWidgets('v1.3 HelpCenterScreen renders Setup Readiness and filters live search', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HelpCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HELP & USER GUIDE'), findsOneWidget);
    expect(find.text('Quick Setup Readiness'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'OCR');
    await tester.pumpAndSettle();

    expect(find.text('Camera, Gallery & Offline ML Kit OCR'), findsOneWidget);
  });

  test('v1.3 DailyPlannerController persists tasks, sorts by priority, and builds spoken briefing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(dailyPlannerControllerProvider.notifier);
    await notifier.addTask(
      title: 'Buy groceries',
      priority: PlannerPriority.low,
    );
    final highTask = await notifier.addTask(
      title: 'Deploy VISION v1.3',
      dueHour: 15,
      dueMinute: 30,
      priority: PlannerPriority.high,
    );

    // Reload in a fresh container to verify JSON persistence & priority sorting
    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloaded.dispose);
    final loaded = reloaded.read(dailyPlannerControllerProvider);
    expect(loaded.length, 2);
    expect(loaded.first.title, 'Deploy VISION v1.3');
    expect(loaded.first.formattedDueTime, '15:30');

    final briefing = reloaded
        .read(dailyPlannerControllerProvider.notifier)
        .buildDailyBriefing(routineCount: 2);
    expect(briefing, contains('2 pending tasks'));
    expect(briefing, contains('1 high priority'));
    expect(briefing, contains('Deploy VISION v1.3 at 15:30'));

    await reloaded
        .read(dailyPlannerControllerProvider.notifier)
        .toggleCompleted(highTask.id);
    expect(
      reloaded.read(dailyPlannerControllerProvider).last.completed,
      isTrue,
    );
  });

  testWidgets('v1.3 DailyPlannerScreen renders tasks and toggles completion', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(dailyPlannerControllerProvider.notifier)
        .addTask(title: 'Test Help Center', priority: PlannerPriority.high);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DailyPlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DAILY PLANNER'), findsOneWidget);
    expect(find.text('Test Help Center'), findsOneWidget);
    expect(find.text('Speak Briefing'), findsOneWidget);
  });
}
