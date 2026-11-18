import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_navigation.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Root navigation shell hosting the floating Liquid Glass bottom bar across
/// Home, Chat, Assistant trigger, Automation, and Settings.
class VisionShellScaffold extends ConsumerWidget {
  const VisionShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<VisionNavItem> _navItems = <VisionNavItem>[
    VisionNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    VisionNavItem(
      label: 'Chat',
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
    ),
    VisionNavItem(
      label: 'Assistant',
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      isPrimaryAssistant: true,
    ),
    VisionNavItem(
      label: 'Automation',
      icon: Icons.bolt_outlined,
      activeIcon: Icons.bolt_rounded,
    ),
    VisionNavItem(
      label: 'Settings',
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
    ),
  ];

  int _navIndexFromBranch(int branchIndex) {
    return switch (branchIndex) {
      0 => 0,
      1 => 1,
      2 => 3,
      3 => 4,
      _ => 0,
    };
  }

  void _onNavTap(BuildContext context, WidgetRef ref, int navIndex) {
    final haptics = ref.read(
      settingsControllerProvider.select((s) => s.hapticFeedbackEnabled),
    );
    if (haptics) {
      unawaited(HapticFeedback.selectionClick());
    }

    if (navIndex == 2) {
      context.push(AppRoutes.assistantPath);
      return;
    }

    final branchIndex = switch (navIndex) {
      0 => 0,
      1 => 1,
      3 => 2,
      4 => 3,
      _ => 0,
    };

    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(
      voiceControllerProvider.select((s) => s.wakeTriggerSequence),
      (previous, next) {
        if (next > (previous ?? 0) && context.mounted) {
          final currentLoc = GoRouterState.of(context).matchedLocation;
          if (currentLoc != AppRoutes.assistantPath &&
              currentLoc != AppRoutes.assistantOverlayPath) {
            context.push(AppRoutes.assistantPath);
          }
        }
      },
    );

    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 80;
    final currentNavIndex = _navIndexFromBranch(navigationShell.currentIndex);

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: keyboardVisible
            ? null
            : VisionGlassNavigationBar(
                items: _navItems,
                currentIndex: currentNavIndex,
                onSelect: (index) => _onNavTap(context, ref, index),
              ),
      ),
    );
  }
}
