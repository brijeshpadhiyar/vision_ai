import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:vision_ai/app/app.dart';
import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_dark_theme.dart';
import 'package:vision_ai/core/theme/vision_light_theme.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/theme/vision_typography.dart';
import 'package:vision_ai/core/widgets/vision_bottom_sheet.dart';
import 'package:vision_ai/core/widgets/vision_card.dart';
import 'package:vision_ai/core/widgets/vision_dialog.dart';
import 'package:vision_ai/core/widgets/vision_empty_view.dart';
import 'package:vision_ai/core/widgets/vision_error_view.dart';
import 'package:vision_ai/core/widgets/vision_gradient_card.dart';
import 'package:vision_ai/core/widgets/vision_icon_button.dart';
import 'package:vision_ai/core/widgets/vision_loading.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';
import 'package:vision_ai/core/widgets/vision_secondary_button.dart';
import 'package:vision_ai/core/widgets/vision_text_field.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_orb.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Typography & Offline Manrope Font Configuration', () {
    test(
      'All 4 static Manrope TTF font assets are bundled in assets/fonts/',
      () {
        const files = <String>[
          'assets/fonts/Manrope-Regular.ttf',
          'assets/fonts/Manrope-Medium.ttf',
          'assets/fonts/Manrope-SemiBold.ttf',
          'assets/fonts/Manrope-Bold.ttf',
        ];
        for (final path in files) {
          final file = File(path);
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Missing bundled font: $path',
          );
          expect(
            file.lengthSync(),
            greaterThan(10000),
            reason: 'Font file appears empty or corrupted: $path',
          );
        }
      },
    );

    test(
      'Complete Material 3 TextTheme configures all 15 roles with Manrope',
      () {
        for (final brightness in Brightness.values) {
          final textTheme = VisionTypography.buildTextTheme(brightness);
          final styles = <TextStyle?>[
            textTheme.displayLarge,
            textTheme.displayMedium,
            textTheme.displaySmall,
            textTheme.headlineLarge,
            textTheme.headlineMedium,
            textTheme.headlineSmall,
            textTheme.titleLarge,
            textTheme.titleMedium,
            textTheme.titleSmall,
            textTheme.bodyLarge,
            textTheme.bodyMedium,
            textTheme.bodySmall,
            textTheme.labelLarge,
            textTheme.labelMedium,
            textTheme.labelSmall,
          ];

          for (final style in styles) {
            expect(style, isNotNull);
            expect(
              style!.fontFamily,
              contains('Manrope'),
              reason: 'Expected Manrope font family on all M3 TextTheme roles',
            );
          }
        }
      },
    );
  });

  group('FlexColorScheme Dark & Light Theme Integration', () {
    test(
      'Midnight Violet dark theme preserves exact brand tokens and M3 themes',
      () {
        final theme = VisionDarkTheme.build();
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, Brightness.dark);
        expect(theme.scaffoldBackgroundColor, const Color(0xFF101016));
        expect(theme.colorScheme.surface, const Color(0xFF191823));
        expect(
          theme.colorScheme.surfaceContainerHighest,
          const Color(0xFF22212E),
        );
        expect(theme.colorScheme.primary, const Color(0xFFA78BFA));
        expect(theme.colorScheme.secondary, const Color(0xFF65E6C1));
        expect(theme.colorScheme.tertiary, const Color(0xFFF0A6C8));
        expect(theme.colorScheme.onSurface, const Color(0xFFF5F1FA));
        expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFB6B0C2));
        expect(theme.colorScheme.outline, const Color(0xFF302D3C));

        final ext = theme.extension<VisionThemeExtension>();
        expect(ext, isNotNull);
        expect(ext!.background, VisionColors.darkBackground);
      },
    );

    test(
      'Pearl Lavender light theme preserves exact brand tokens and M3 themes',
      () {
        final theme = VisionLightTheme.build();
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, Brightness.light);
        expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F5FA));
        expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
        expect(theme.colorScheme.primary, const Color(0xFF7554C7));
        expect(theme.colorScheme.secondary, const Color(0xFF168D73));
        expect(theme.colorScheme.tertiary, const Color(0xFFB65F89));
        expect(theme.colorScheme.onSurface, const Color(0xFF211B2B));
        expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF696273));
        expect(theme.colorScheme.outline, const Color(0xFFE5DFEB));

        final ext = theme.extension<VisionThemeExtension>();
        expect(ext, isNotNull);
        expect(ext!.background, VisionColors.lightBackground);
      },
    );
  });

  group('VisionOrb — Rive Integration & 6 Real States', () {
    test(
      'VisionOrbStateResolver strictly reflects real state without faking',
      () {
        expect(
          VisionOrbStateResolver.resolve(
            isListening: false,
            isThinking: false,
            isSpeaking: false,
            hasError: false,
            isOffline: false,
          ),
          VisionOrbState.idle,
        );
        expect(
          VisionOrbStateResolver.resolve(
            isListening: true,
            isThinking: false,
            isSpeaking: false,
            hasError: false,
            isOffline: false,
          ),
          VisionOrbState.listening,
        );
        expect(
          VisionOrbStateResolver.resolve(
            isListening: false,
            isThinking: true,
            isSpeaking: false,
            hasError: false,
            isOffline: false,
          ),
          VisionOrbState.thinking,
        );
        expect(
          VisionOrbStateResolver.resolve(
            isListening: false,
            isThinking: false,
            isSpeaking: true,
            hasError: false,
            isOffline: false,
          ),
          VisionOrbState.speaking,
        );
        expect(
          VisionOrbStateResolver.resolve(
            isListening: false,
            isThinking: false,
            isSpeaking: false,
            hasError: true,
            isOffline: false,
          ),
          VisionOrbState.error,
        );
        expect(
          VisionOrbStateResolver.resolve(
            isListening: true,
            isThinking: true,
            isSpeaking: true,
            hasError: true,
            isOffline: true,
          ),
          VisionOrbState.offline,
        );
      },
    );

    testWidgets('VisionOrb renders Flutter-native fallback for all 6 states', (
      tester,
    ) async {
      for (final state in VisionOrbState.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: VisionLightTheme.build(),
            darkTheme: VisionDarkTheme.build(),
            themeMode: ThemeMode.dark,
            home: Scaffold(
              body: Center(
                child: VisionOrb(
                  size: 140,
                  state: state,
                  audioLevel: state == VisionOrbState.listening ? 0.6 : 0.0,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(VisionAiOrb), findsOneWidget);
      }
    });
  });

  group('Skeletonizer Loading Widgets', () {
    testWidgets(
      'All 5 skeleton placeholders render cleanly in dark and light themes',
      (tester) async {
        for (final theme in <ThemeData>[
          VisionDarkTheme.build(),
          VisionLightTheme.build(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => SkeletonizerConfig(
                data: VisionApp.buildSkeletonizerConfig(
                  brightness: theme.brightness,
                  reducedMotion: false,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      VisionLoading.providerCard(),
                      VisionLoading.modelList(itemCount: 2),
                      VisionLoading.chatPlaceholder(),
                      VisionLoading.settingsSection(itemCount: 2),
                      VisionLoading.conversationList(itemCount: 2),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(VisionLoading), findsNWidgets(5));
        }
      },
    );
  });

  group('Reusable Components & flutter_animate Presets', () {
    testWidgets(
      'Cards, buttons, dialogs, sheets, empty/error views render cleanly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VisionDarkTheme.build(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const VisionCard(
                      animateEntrance: true,
                      entranceIndex: 0,
                      child: Text('Card'),
                    ),
                    VisionGradientCard(
                      animateEntrance: true,
                      onTap: () {},
                      child: const Text('Gradient Card'),
                    ),
                    VisionPrimaryButton(label: 'Primary', onPressed: () {}),
                    VisionSecondaryButton(label: 'Secondary', onPressed: () {}),
                    VisionIconButton(
                      icon: Icons.auto_awesome_rounded,
                      onPressed: () {},
                    ),
                    const VisionTextField(labelText: 'Prompt'),
                    const VisionEmptyView(
                      title: 'Empty',
                      message: 'No items yet',
                    ),
                    const VisionErrorView(
                      title: 'Error',
                      message: 'Something went wrong',
                    ),
                    const VisionBottomSheet(
                      title: 'Sheet',
                      child: Text('Body'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Card'), findsOneWidget);
        expect(find.text('Gradient Card'), findsOneWidget);
        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('Secondary'), findsOneWidget);
        expect(find.text('Empty'), findsOneWidget);
        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Sheet'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            theme: VisionDarkTheme.build(),
            home: Builder(
              builder: (context) => VisionDialog(
                title: 'Confirm',
                content: const Text('Dialog body'),
                actions: <Widget>[
                  VisionPrimaryButton(label: 'OK', onPressed: () {}),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Confirm'), findsOneWidget);
      },
    );

    testWidgets(
      'Reduced motion disables continuous shimmer/breathing animations',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              theme: VisionDarkTheme.build(),
              home: Builder(
                builder: (context) {
                  expect(VisionAnimations.isReducedMotion(context), isTrue);
                  expect(VisionAnimations.shouldAnimate(context), isFalse);
                  return Scaffold(
                    body: Column(
                      children: <Widget>[
                        const Text('Static').visionShimmer(context),
                        const Text('Calm').visionSubtleBreathing(context),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Static'), findsOneWidget);
        expect(find.text('Calm'), findsOneWidget);
      },
    );
  });
}
