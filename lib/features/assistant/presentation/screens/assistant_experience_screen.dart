import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_brand_logo.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Dedicated full-screen Liquid Glass Voice Assistant experience.
///
/// Used both for in-app assistant activation (`/assistant`) and Android
/// `AssistantOverlayActivity` / `VoiceInteractionSession` (`/assistant-overlay`).
class AssistantExperienceScreen extends ConsumerStatefulWidget {
  const AssistantExperienceScreen({
    super.key,
    this.isSystemOverlay = false,
    this.autoListenOnOpen = false,
  });

  final bool isSystemOverlay;
  final bool autoListenOnOpen;

  @override
  ConsumerState<AssistantExperienceScreen> createState() =>
      _AssistantExperienceScreenState();
}

class _AssistantExperienceScreenState
    extends ConsumerState<AssistantExperienceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _backdropController;
  final TextEditingController _textInputController = TextEditingController();
  bool _showKeyboardInput = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _backdropController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapSession());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = VisionAnimations.isReducedMotion(context);
    if (reduce != _reducedMotion) {
      _reducedMotion = reduce;
      if (_reducedMotion) {
        _backdropController.stop();
      } else if (!_backdropController.isAnimating) {
        _backdropController.repeat(reverse: true);
      }
    }
  }

  Future<void> _bootstrapSession() async {
    if (!mounted) return;
    final notifier = ref.read(voiceControllerProvider.notifier);
    if (widget.isSystemOverlay) {
      await notifier.checkQueuedOverlayPrompt();
      if (!mounted) return;
    }
    if (widget.isSystemOverlay || widget.autoListenOnOpen) {
      final state = ref.read(voiceControllerProvider);
      if (state.phase == VoiceListeningPhase.idle && !state.isListening) {
        await notifier.startCommandListening();
      }
    }
  }

  @override
  void dispose() {
    _backdropController.dispose();
    _textInputController.dispose();
    super.dispose();
  }

  Future<void> _handleMicOrOrbTap(VoiceSessionState voiceState) async {
    final settings = ref.read(settingsControllerProvider);
    if (settings.hapticFeedbackEnabled) {
      unawaited(HapticFeedback.lightImpact());
    }
    final voiceNotifier = ref.read(voiceControllerProvider.notifier);
    if (voiceState.isSpeaking) {
      await voiceNotifier.interruptAndListen();
    } else {
      await voiceNotifier.toggleVoiceCapture();
    }
  }

  Future<void> _handleStopTap(VoiceSessionState voiceState) async {
    final settings = ref.read(settingsControllerProvider);
    if (settings.hapticFeedbackEnabled) {
      unawaited(HapticFeedback.selectionClick());
    }
    final voiceNotifier = ref.read(voiceControllerProvider.notifier);
    if (voiceState.isSpeaking) {
      await voiceNotifier.stopSpeaking();
    }
    if (voiceState.isListening) {
      await voiceNotifier.cancelListening();
    }
    ref.read(chatControllerProvider.notifier).cancelActiveRequest();
  }

  Future<void> _handleFinishListening() async {
    final settings = ref.read(settingsControllerProvider);
    if (settings.hapticFeedbackEnabled) {
      unawaited(HapticFeedback.lightImpact());
    }
    await ref.read(voiceControllerProvider.notifier).finishListening();
  }

  Future<void> _handleSendTextPrompt() async {
    final text = _textInputController.text.trim();
    if (text.isEmpty) return;

    final settings = ref.read(settingsControllerProvider);
    if (settings.hapticFeedbackEnabled) {
      unawaited(HapticFeedback.lightImpact());
    }

    _textInputController.clear();
    FocusScope.of(context).unfocus();

    final accepted = await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(text);
    if (!mounted) return;

    final chatState = ref.read(chatControllerProvider);
    if (accepted &&
        chatState.messages.isNotEmpty &&
        chatState.messages.last.sender == MessageSender.assistant &&
        settings.autoSpeakReplies) {
      await ref
          .read(voiceControllerProvider.notifier)
          .speakReply(chatState.messages.last.content);
    }
  }

  void _handleDismiss() {
    if (widget.isSystemOverlay) {
      SystemNavigator.pop();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.homePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);
    final chatState = ref.watch(chatControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final automationState = ref.watch(automationControllerProvider);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final isThinking =
        voiceState.phase == VoiceListeningPhase.finalizing ||
        voiceState.phase == VoiceListeningPhase.processingAi ||
        voiceState.phase == VoiceListeningPhase.understanding ||
        voiceState.phase == VoiceListeningPhase.executing ||
        (chatState.isLoading && !voiceState.isListening);
    final hasError =
        voiceState.phase == VoiceListeningPhase.error ||
        voiceState.errorMessage != null;

    final orbState = hasError
        ? VisionOrbState.error
        : voiceState.isListening
        ? VisionOrbState.listening
        : isThinking
        ? VisionOrbState.thinking
        : voiceState.isSpeaking
        ? VisionOrbState.speaking
        : VisionOrbState.idle;

    final dynamicStateText = switch (voiceState.phase) {
      VoiceListeningPhase.listeningCommand =>
        voiceState.liveTranscript.trim().isNotEmpty
            ? 'Hearing you...'
            : 'Listening...',
      VoiceListeningPhase.partialTranscription => 'Hearing you...',
      VoiceListeningPhase.endpointing => 'Pause detected — listening...',
      VoiceListeningPhase.finalizing => 'Finalizing speech...',
      VoiceListeningPhase.listeningWakeWord => 'Standby • Say "Hey VISION"',
      VoiceListeningPhase.understanding => 'Understanding...',
      VoiceListeningPhase.processingAi => 'Thinking...',
      VoiceListeningPhase.executing => 'Executing Action...',
      VoiceListeningPhase.confirmationRequired => 'Confirm Selection',
      VoiceListeningPhase.speaking => 'Speaking...',
      VoiceListeningPhase.error => 'Attention needed',
      VoiceListeningPhase.requestingPermission => 'Permission Needed',
      VoiceListeningPhase.cancelled =>
        voiceState.isWakeServiceRunning
            ? 'Standby • Say "Hey VISION"'
            : 'Cancelled.',
      VoiceListeningPhase.idle =>
        isThinking
            ? 'Thinking...'
            : voiceState.isWakeServiceRunning
            ? 'Standby • Say "Hey VISION"'
            : 'Ready.',
    };

    final stateAccent = switch (orbState) {
      VisionOrbState.listening => VisionColors.success,
      VisionOrbState.thinking => VisionColors.accentSecondary,
      VisionOrbState.speaking => VisionColors.accentPrimary,
      VisionOrbState.error => VisionColors.semanticError(brightness),
      VisionOrbState.offline => VisionColors.mutedText(brightness),
      VisionOrbState.idle => VisionColors.primaryAccent(brightness),
    };

    // Show live streaming AI reply when thinking/speaking, or latest voice reply.
    final latestAssistantMessage =
        chatState.messages.isNotEmpty &&
            chatState.messages.last.sender == MessageSender.assistant
        ? chatState.messages.last.content
        : '';
    final visibleResponse = voiceState.lastReplyText.isNotEmpty
        ? voiceState.lastReplyText
        : (isThinking || _showKeyboardInput)
        ? latestAssistantMessage
        : '';

    final canStop =
        voiceState.isListening || voiceState.isSpeaking || isThinking;

    return Scaffold(
      backgroundColor: widget.isSystemOverlay
          ? VisionColors.backgroundPrimary.withValues(alpha: 0.86)
          : VisionColors.primaryBackground(brightness),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AnimatedAssistantBackdrop(
            controller: _backdropController,
            accentColor: stateAccent,
            isSystemOverlay: widget.isSystemOverlay,
            isDark: isDark,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isShort = constraints.maxHeight < 640;
                final orbSize = math.min(
                  isShort ? 156.0 : 214.0,
                  constraints.maxWidth * 0.56,
                );

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppConstants.maxContentWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                      child: Column(
                        children: [
                          // ── Top Section: Brand & Status ──────────────────
                          _AssistantTopBar(
                            providerLabel:
                                '${settings.selectedAiProvider.displayName} • ${settings.selectedVoiceLanguage.localeCode}',
                            isWakeActive: voiceState.isWakeServiceRunning,
                            onOpenChat: () => context.go(AppRoutes.chatPath),
                            onDismiss: _handleDismiss,
                          ),

                          // ── Center Scrollable Stage ──────────────────────
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: math.max(
                                    0,
                                    constraints.maxHeight - 170,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    VisionAiOrb(
                                      size: orbSize,
                                      state: orbState,
                                      audioLevel:
                                          voiceState.normalizedAmplitude,
                                      onTap: () =>
                                          _handleMicOrOrbTap(voiceState),
                                    ),
                                    if (voiceState.isListening ||
                                        voiceState.isSpeaking) ...[
                                      const SizedBox(height: 10),
                                      _VoiceWaveformBars(
                                        amplitude:
                                            voiceState.normalizedAmplitude,
                                        color: stateAccent,
                                        isActive: true,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    AnimatedSwitcher(
                                      duration:
                                          VisionAnimations.resolveDuration(
                                            context,
                                            VisionAnimations.micro,
                                          ),
                                      child: Text(
                                        dynamicStateText,
                                        key: ValueKey<String>(dynamicStateText),
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              color: stateAccent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${settings.selectedVoiceLanguage.displayName} • ${settings.selectedModelId}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 18),

                                    // ── Live Speech Transcription ──────────
                                    _AssistantTranscriptPanel(
                                      transcript: voiceState.liveTranscript,
                                      errorMessage:
                                          voiceState.errorMessage ??
                                          chatState.errorMessage,
                                      isListening: voiceState.isListening,
                                      isEndpointing:
                                          voiceState.phase ==
                                          VoiceListeningPhase.endpointing,
                                      segmentCount: voiceState.segmentCount,
                                      onFinishTap:
                                          voiceState.isListening &&
                                              voiceState.liveTranscript
                                                  .trim()
                                                  .isNotEmpty
                                          ? _handleFinishListening
                                          : null,
                                    ),

                                    // ── Concise AI Response Preview ────────
                                    if (visibleResponse.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      _AssistantReplyCard(
                                        replyText: visibleResponse,
                                        isStreaming: isThinking,
                                        onOpenFullChat: () =>
                                            context.go(AppRoutes.chatPath),
                                      ),
                                    ],

                                    // ── Pending Device Action Prompts ──────
                                    if (automationState.pendingConfirmation !=
                                            null ||
                                        automationState
                                            .contactChoices
                                            .isNotEmpty ||
                                        automationState
                                                .lastResult
                                                ?.requiresPermission ==
                                            true) ...[
                                      const SizedBox(height: 12),
                                      AutomationActionPromptCard(
                                        automationState: automationState,
                                        compact: true,
                                        onConfirm: () => unawaited(
                                          ref
                                              .read(
                                                automationControllerProvider
                                                    .notifier,
                                              )
                                              .confirmPendingAction(),
                                        ),
                                        onConfirmAndSaveAlias: () => unawaited(
                                          ref
                                              .read(
                                                automationControllerProvider
                                                    .notifier,
                                              )
                                              .confirmPendingAction(
                                                saveAsAlias: true,
                                              ),
                                        ),
                                        onCancel: () => ref
                                            .read(
                                              automationControllerProvider
                                                  .notifier,
                                            )
                                            .cancelPendingAction(),
                                        onSelectContact: (c) => unawaited(
                                          ref
                                              .read(
                                                automationControllerProvider
                                                    .notifier,
                                              )
                                              .selectContactForPendingAction(c),
                                        ),
                                        onGrantPermission: (p) => unawaited(
                                          ref
                                              .read(
                                                automationControllerProvider
                                                    .notifier,
                                              )
                                              .requestPermission(p),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── Optional Keyboard Input ──────────────────────
                          if (_showKeyboardInput) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: VisionGlassInput(
                                      controller: _textInputController,
                                      autofocus: true,
                                      hintText: 'Type a command or question...',
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) =>
                                          _handleSendTextPrompt(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  VisionGlassIconButton(
                                    icon: Icons.send_rounded,
                                    tooltip: 'Send prompt',
                                    isActive: true,
                                    size: 48,
                                    onPressed: _handleSendTextPrompt,
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // ── Bottom Controls: Keyboard, Mic, Stop, Dismiss
                          _AssistantControlsBar(
                            orbState: orbState,
                            canStop: canStop,
                            showKeyboard: _showKeyboardInput,
                            onToggleKeyboard: () => setState(
                              () => _showKeyboardInput = !_showKeyboardInput,
                            ),
                            onMicTap: () => _handleMicOrOrbTap(voiceState),
                            onStopTap: () => _handleStopTap(voiceState),
                            onDismissTap: _handleDismiss,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedAssistantBackdrop extends StatelessWidget {
  const _AnimatedAssistantBackdrop({
    required this.controller,
    required this.accentColor,
    required this.isSystemOverlay,
    required this.isDark,
  });

  final Animation<double> controller;
  final Color accentColor;
  final bool isSystemOverlay;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            final centerY = -0.25 + (t * 0.16);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isSystemOverlay
                      ? [
                          VisionColors.backgroundPrimary.withValues(
                            alpha: 0.72,
                          ),
                          VisionColors.backgroundSecondary.withValues(
                            alpha: 0.88,
                          ),
                          VisionColors.backgroundPrimary.withValues(
                            alpha: 0.94,
                          ),
                        ]
                      : isDark
                      ? [
                          VisionColors.backgroundPrimary,
                          VisionColors.backgroundSecondary,
                          VisionColors.backgroundPrimary,
                        ]
                      : [
                          VisionColors.lightBackgroundPrimary,
                          VisionColors.lightBackgroundSecondary,
                          VisionColors.lightBackgroundPrimary,
                        ],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, centerY),
                    radius: 0.92,
                    colors: [
                      accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
                      VisionColors.accentSecondary.withValues(
                        alpha: isDark ? 0.10 : 0.06,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AssistantTopBar extends StatelessWidget {
  const _AssistantTopBar({
    required this.providerLabel,
    required this.isWakeActive,
    required this.onOpenChat,
    required this.onDismiss,
  });

  final String providerLabel;
  final bool isWakeActive;
  final VoidCallback onOpenChat;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const VisionBrandLogo(size: 28, showAmbientGlow: false),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isWakeActive) ...[
                    const SizedBox(width: 8),
                    const VisionStatusBadge(
                      label: 'Wake',
                      indicatorColor: VisionColors.success,
                      compact: true,
                    ),
                  ],
                ],
              ),
              Text(
                providerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
        VisionGlassIconButton(
          icon: Icons.forum_outlined,
          tooltip: 'Open Chat History',
          onPressed: onOpenChat,
        ),
        const SizedBox(width: 8),
        VisionGlassIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close Assistant',
          onPressed: onDismiss,
        ),
      ],
    );
  }
}

class _AssistantTranscriptPanel extends StatelessWidget {
  const _AssistantTranscriptPanel({
    required this.transcript,
    required this.isListening,
    this.isEndpointing = false,
    this.segmentCount = 0,
    this.onFinishTap,
    this.errorMessage,
  });

  final String transcript;
  final bool isListening;
  final bool isEndpointing;
  final int segmentCount;
  final VoidCallback? onFinishTap;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return VisionGlassContainer(
        variant: VisionGlassVariant.standard,
        borderColor: VisionColors.error.withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: VisionColors.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: VisionColors.primaryText(brightness),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final displayText = transcript.trim().isNotEmpty
        ? '"$transcript"'
        : isListening
        ? 'Speak clearly in English, Hindi, or Gujarati...'
        : 'Tap the orb or microphone to speak with VISION.';

    final subtitle = isEndpointing
        ? 'Pause detected — keep speaking or tap Done'
        : isListening && segmentCount > 1
        ? 'Captured $segmentCount speech segments'
        : null;

    return VisionGlassContainer(
      variant: transcript.trim().isNotEmpty
          ? VisionGlassVariant.accent
          : VisionGlassVariant.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayText,
            textAlign: TextAlign.center,
            style: transcript.trim().isNotEmpty
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium,
          ),
          if (subtitle != null || onFinishTap != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: VisionColors.secondaryText(brightness),
                    ),
                  ),
                if (onFinishTap != null)
                  VisionGlassButton(
                    compact: true,
                    icon: Icons.check_rounded,
                    label: 'Done',
                    onPressed: onFinishTap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AssistantReplyCard extends StatelessWidget {
  const _AssistantReplyCard({
    required this.replyText,
    required this.isStreaming,
    required this.onOpenFullChat,
  });

  final String replyText;
  final bool isStreaming;
  final VoidCallback onOpenFullChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return VisionGlassCard(
      variant: VisionGlassVariant.elevated,
      padding: const EdgeInsets.all(16),
      onTap: onOpenFullChat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: VisionColors.primaryAccent(brightness),
              ),
              const SizedBox(width: 8),
              Text(
                'VISION Response',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: VisionColors.primaryAccent(brightness),
                ),
              ),
              const Spacer(),
              if (isStreaming)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.open_in_new_rounded,
                  size: 15,
                  color: VisionColors.secondaryText(brightness),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            replyText,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _AssistantControlsBar extends StatelessWidget {
  const _AssistantControlsBar({
    required this.orbState,
    required this.canStop,
    required this.showKeyboard,
    required this.onToggleKeyboard,
    required this.onMicTap,
    required this.onStopTap,
    required this.onDismissTap,
  });

  final VisionOrbState orbState;
  final bool canStop;
  final bool showKeyboard;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onMicTap;
  final VoidCallback onStopTap;
  final VoidCallback onDismissTap;

  @override
  Widget build(BuildContext context) {
    final isListening = orbState == VisionOrbState.listening;
    final isSpeaking = orbState == VisionOrbState.speaking;
    final micColor = isListening
        ? VisionColors.success
        : isSpeaking
        ? VisionColors.warning
        : VisionColors.accentPrimary;

    return VisionGlassContainer(
      variant: VisionGlassVariant.elevated,
      blurSigma: VisionGlass.blurStandard,
      borderRadius: VisionRadii.xlBorder,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          VisionGlassIconButton(
            icon: showKeyboard
                ? Icons.keyboard_hide_rounded
                : Icons.keyboard_rounded,
            tooltip: showKeyboard ? 'Hide keyboard' : 'Type command',
            isActive: showKeyboard,
            onPressed: onToggleKeyboard,
          ),
          VisionGlassIconButton(
            icon: Icons.stop_rounded,
            tooltip: canStop ? 'Stop active task' : 'Nothing active to stop',
            iconColor: canStop
                ? VisionColors.error
                : VisionColors.mutedText(Theme.of(context).brightness),
            glowColor: VisionColors.error,
            isActive: canStop,
            onPressed: canStop ? onStopTap : null,
          ),
          Semantics(
            button: true,
            label: isListening
                ? 'Stop listening'
                : isSpeaking
                ? 'Interrupt and listen'
                : 'Start voice command',
            child: GestureDetector(
              onTap: onMicTap,
              child: AnimatedContainer(
                duration: VisionAnimations.resolveDuration(
                  context,
                  VisionAnimations.micro,
                ),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [micColor, VisionColors.accentSecondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: micColor.withValues(alpha: 0.45),
                      blurRadius: isListening ? 24 : 16,
                      spreadRadius: isListening ? 3 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  isListening
                      ? Icons.graphic_eq_rounded
                      : isSpeaking
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? VisionColors.backgroundPrimary
                      : Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          VisionGlassIconButton(
            icon: Icons.forum_outlined,
            tooltip: 'Open Chat',
            onPressed: () => context.go(AppRoutes.chatPath),
          ),
          VisionGlassIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Dismiss Assistant',
            onPressed: onDismissTap,
          ),
        ],
      ),
    );
  }
}

class _VoiceWaveformBars extends StatelessWidget {
  const _VoiceWaveformBars({
    required this.amplitude,
    required this.color,
    required this.isActive,
  });

  final double amplitude;
  final Color color;
  final bool isActive;

  static const List<double> _weights = <double>[
    0.45,
    0.72,
    0.95,
    1.0,
    0.95,
    0.72,
    0.45,
  ];

  @override
  Widget build(BuildContext context) {
    final normalized = isActive ? amplitude.clamp(0.18, 1.0) : 0.12;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final w in _weights)
          AnimatedContainer(
            duration: VisionAnimations.resolveDuration(
              context,
              const Duration(milliseconds: 120),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 4,
            height: 6 + (normalized * w * 22),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
