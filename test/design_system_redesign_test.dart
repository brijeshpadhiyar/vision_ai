import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_dark_theme.dart';
import 'package:vision_ai/core/theme/vision_light_theme.dart';
import 'package:vision_ai/core/theme/vision_motion.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/core/widgets/vision_empty_view.dart';
import 'package:vision_ai/core/widgets/vision_error_view.dart';
import 'package:vision_ai/core/widgets/vision_glass_panel.dart';
import 'package:vision_ai/core/widgets/vision_gradient_card.dart';
import 'package:vision_ai/core/widgets/vision_icon_button.dart';
import 'package:vision_ai/core/widgets/vision_loading.dart';
import 'package:vision_ai/core/widgets/vision_orb.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';
import 'package:vision_ai/core/widgets/vision_secondary_button.dart';
import 'package:vision_ai/core/widgets/vision_section_header.dart';
import 'package:vision_ai/core/widgets/vision_text_field.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

void main() {
  group('VISION AI Midnight Violet + Pearl Lavender Design System', () {
    test('Exact Midnight Violet dark & Pearl Lavender light color tokens match specification', () {
      // Dark Theme — Midnight Violet
      expect(VisionColorTokens.dark.background, const Color(0xFF101016));
      expect(
        VisionColorTokens.dark.secondaryBackground,
        const Color(0xFF15151E),
      );
      expect(VisionColorTokens.dark.surface, const Color(0xFF191823));
      expect(VisionColorTokens.dark.elevatedSurface, const Color(0xFF22212E));
      expect(VisionColorTokens.dark.primary, const Color(0xFFA78BFA));
      expect(VisionColorTokens.dark.primaryContainer, const Color(0xFF35284E));
      expect(VisionColorTokens.dark.secondary, const Color(0xFF65E6C1));
      expect(VisionColorTokens.dark.tertiary, const Color(0xFFF0A6C8));
      expect(VisionColorTokens.dark.textPrimary, const Color(0xFFF5F1FA));
      expect(VisionColorTokens.dark.textSecondary, const Color(0xFFB6B0C2));
      expect(VisionColorTokens.dark.border, const Color(0xFF302D3C));
      expect(VisionColorTokens.dark.success, const Color(0xFF65D6A5));
      expect(VisionColorTokens.dark.warning, const Color(0xFFF4BD70));
      expect(VisionColorTokens.dark.error, const Color(0xFFFF858D));

      // Light Theme — Pearl Lavender
      expect(VisionColorTokens.light.background, const Color(0xFFF7F5FA));
      expect(
        VisionColorTokens.light.secondaryBackground,
        const Color(0xFFF0EDF5),
      );
      expect(VisionColorTokens.light.surface, const Color(0xFFFFFFFF));
      expect(VisionColorTokens.light.elevatedSurface, const Color(0xFFFFFFFF));
      expect(VisionColorTokens.light.primary, const Color(0xFF7554C7));
      expect(VisionColorTokens.light.primaryContainer, const Color(0xFFE9DFFF));
      expect(VisionColorTokens.light.secondary, const Color(0xFF168D73));
      expect(VisionColorTokens.light.tertiary, const Color(0xFFB65F89));
      expect(VisionColorTokens.light.textPrimary, const Color(0xFF211B2B));
      expect(VisionColorTokens.light.textSecondary, const Color(0xFF696273));
      expect(VisionColorTokens.light.border, const Color(0xFFE5DFEB));
      expect(VisionColorTokens.light.success, const Color(0xFF187B59));
      expect(VisionColorTokens.light.warning, const Color(0xFFA5681D));
      expect(VisionColorTokens.light.error, const Color(0xFFC23E51));

      // Verify old blue palette is completely removed
      expect(VisionColors.accentPrimary, isNot(const Color(0xFF00D4FF)));
      expect(VisionColors.accentSecondary, isNot(const Color(0xFF3985FF)));
    });

    test('VisionDarkTheme & VisionLightTheme attach VisionThemeExtension and lerp cleanly', () {
      final dark = VisionDarkTheme.build();
      final light = VisionLightTheme.build();

      final darkExt = dark.extension<VisionThemeExtension>();
      final lightExt = light.extension<VisionThemeExtension>();
      expect(darkExt, isNotNull);
      expect(lightExt, isNotNull);
      expect(darkExt!.primary, const Color(0xFFA78BFA));
      expect(lightExt!.primary, const Color(0xFF7554C7));

      final mid = darkExt.lerp(lightExt, 0.5);
      expect(
        mid.background,
        Color.lerp(darkExt.background, lightExt.background, 0.5),
      );
    });

    test(
      'ThemeMode switches at runtime and persists across container restart',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();

        final container1 = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        await container1
            .read(settingsControllerProvider.notifier)
            .setThemeMode(ThemeMode.light);
        expect(
          container1.read(settingsControllerProvider).themeMode,
          ThemeMode.light,
        );
        container1.dispose();

        final container2 = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container2.dispose);
        expect(
          container2.read(settingsControllerProvider).themeMode,
          ThemeMode.light,
        );

        await container2
            .read(settingsControllerProvider.notifier)
            .setThemeMode(ThemeMode.system);
        expect(
          container2.read(settingsControllerProvider).themeMode,
          ThemeMode.system,
        );
      },
    );

    testWidgets(
      'Reusable widget library renders cleanly in both Dark and Light themes',
      (tester) async {
        var primaryTapped = false;
        var retryTapped = false;

        for (final theme in <ThemeData>[
          VisionDarkTheme.build(),
          VisionLightTheme.build(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const VisionSectionHeader(
                        title: 'AI Providers',
                        subtitle: 'Configured backends',
                        icon: Icons.auto_awesome_rounded,
                      ),
                      const SizedBox(height: 12),
                      VisionGradientCard(
                        child: VisionPrimaryButton(
                          label: 'Connect',
                          icon: Icons.bolt_rounded,
                          onPressed: () => primaryTapped = true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      VisionGlassPanel(
                        highlighted: true,
                        child: Row(
                          children: <Widget>[
                            VisionSecondaryButton(
                              label: 'Cancel',
                              onPressed: () {},
                            ),
                            const SizedBox(width: 8),
                            VisionIconButton(
                              icon: Icons.tune_rounded,
                              tooltip: 'Tune',
                              selected: true,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const VisionTextField(hintText: 'Ask VISION...'),
                      const SizedBox(height: 12),
                      VisionLoadingSkeleton.cardPlaceholder(),
                      const SizedBox(height: 12),
                      VisionErrorView(
                        title: 'Offline',
                        message: 'Check internet connection.',
                        onRetry: () => retryTapped = true,
                      ),
                      const SizedBox(height: 12),
                      VisionEmptyView(
                        title: 'No items yet',
                        message: 'Start a conversation.',
                        actionLabel: 'Start',
                        onAction: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          expect(find.text('AI Providers'), findsOneWidget);
          expect(find.text('Connect'), findsOneWidget);
          expect(find.text('Offline'), findsOneWidget);
          expect(find.text('No items yet'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.tap(find.text('Connect'));
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(primaryTapped, isTrue);
        expect(retryTapped, isTrue);
      },
    );

    testWidgets('VisionOrb renders all 6 states and respects reduced motion', (
      tester,
    ) async {
      for (final orbState in VisionOrbState.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: VisionDarkTheme.build(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: VisionOrb(size: 140, state: orbState, audioLevel: 0.4),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(VisionOrb), findsOneWidget);
      }

      // Verify VisionMotion resolves to Duration.zero under disableAnimations
      late Duration resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                resolved = VisionMotion.resolve(context, VisionMotion.standard);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(resolved, Duration.zero);
    });
  });
}
