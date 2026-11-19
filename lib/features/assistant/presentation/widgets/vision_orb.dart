import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rive/rive.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

export 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart'
    show VisionOrbState;

/// Configuration contract for binding a `.riv` Rive animation asset to
/// [VisionOrb]'s 6 operational assistant states.
@immutable
class VisionOrbRiveConfig {
  const VisionOrbRiveConfig({
    required this.assetPath,
    this.artboardName,
    this.stateMachineName = 'VisionOrbStateMachine',
    this.stateNumberInputName = 'orbState',
    this.audioLevelInputName = 'audioLevel',
  });

  /// Asset path to a bundled `.riv` file (e.g. `assets/animations/vision_orb.riv`).
  final String assetPath;

  /// Optional artboard name; defaults to the Rive file's default artboard.
  final String? artboardName;

  /// State machine name inside the `.riv` file.
  final String stateMachineName;

  /// Numeric state machine input index mapped to [VisionOrbState.index]:
  /// `0 = idle`, `1 = listening`, `2 = thinking`, `3 = speaking`,
  /// `4 = error`, `5 = offline`.
  final String stateNumberInputName;

  /// Normalized audio amplitude input (`0.0` to `1.0`).
  final String audioLevelInputName;
}

/// Pure resolver deriving [VisionOrbState] strictly from real assistant, voice,
/// chat, and connectivity states — never simulating speaking or listening.
abstract final class VisionOrbStateResolver {
  static VisionOrbState resolve({
    required bool isListening,
    required bool isThinking,
    required bool isSpeaking,
    required bool hasError,
    required bool isOffline,
  }) {
    if (isOffline) return VisionOrbState.offline;
    if (hasError) return VisionOrbState.error;
    if (isListening) return VisionOrbState.listening;
    if (isThinking) return VisionOrbState.thinking;
    if (isSpeaking) return VisionOrbState.speaking;
    return VisionOrbState.idle;
  }
}

/// Reusable 6-state VISION AI Orb (`idle`, `listening`, `thinking`, `speaking`,
/// `error`, `offline`).
///
/// Uses the Rive Flutter runtime (`rive` 0.14.x / `rive_native`) when a valid
/// [riveConfig] `.riv` asset is provided, and seamlessly falls back to the
/// theme-aware Flutter-native [VisionAiOrb] when no `.riv` asset exists or if
/// asset loading fails.
class VisionOrb extends StatefulWidget {
  const VisionOrb({
    super.key,
    this.size = AppConstants.orbBaseSize,
    this.state = VisionOrbState.idle,
    this.audioLevel = 0.0,
    this.onTap,
    this.semanticLabel = 'VISION AI interactive orb',
    this.riveConfig,
  });

  final double size;
  final VisionOrbState state;

  /// Normalized microphone or TTS amplitude in `[0.0, 1.0]`.
  final double audioLevel;
  final VoidCallback? onTap;
  final String semanticLabel;

  /// Optional Rive `.riv` asset configuration. When `null`, the Flutter-native
  /// [VisionAiOrb] renders directly with zero asset-loading overhead.
  final VisionOrbRiveConfig? riveConfig;

  @override
  State<VisionOrb> createState() => _VisionOrbState();
}

class _VisionOrbState extends State<VisionOrb> with WidgetsBindingObserver {
  FileLoader? _fileLoader;
  RiveWidgetController? _riveController;
  NumberInput? _stateInput;
  NumberInput? _audioInput;
  bool _appPaused = false;
  bool _riveLoadFailed = false;

  bool get _hasRiveAsset =>
      widget.riveConfig != null &&
      widget.riveConfig!.assetPath.trim().isNotEmpty &&
      !_riveLoadFailed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFileLoader();
  }

  void _initFileLoader() {
    _disposeRive();
    final config = widget.riveConfig;
    if (config == null || config.assetPath.trim().isEmpty) return;
    _riveLoadFailed = false;
    _fileLoader = FileLoader.fromAsset(
      config.assetPath,
      riveFactory: Factory.rive,
    );
  }

  @override
  void didUpdateWidget(covariant VisionOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.riveConfig?.assetPath != widget.riveConfig?.assetPath ||
        oldWidget.riveConfig?.stateMachineName !=
            widget.riveConfig?.stateMachineName) {
      _initFileLoader();
    }
    _syncRiveInputs();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (paused != _appPaused) {
      _appPaused = paused;
      _syncRiveActive();
    }
  }

  void _bindRiveController(RiveWidgetController controller) {
    _riveController = controller;
    final config = widget.riveConfig;
    if (config != null) {
      // ignore: deprecated_member_use
      _stateInput = controller.stateMachine.number(config.stateNumberInputName);
      // ignore: deprecated_member_use
      _audioInput = controller.stateMachine.number(config.audioLevelInputName);
    }
    _syncRiveInputs();
    _syncRiveActive();
  }

  void _syncRiveInputs() {
    _stateInput?.value = widget.state.index.toDouble();
    _audioInput?.value = widget.audioLevel.clamp(0.0, 1.0);
  }

  void _syncRiveActive() {
    final controller = _riveController;
    if (controller == null || !mounted) return;
    final shouldPlay =
        !_appPaused &&
        VisionAnimations.shouldAnimate(context) &&
        widget.state != VisionOrbState.offline;
    controller.active = shouldPlay;
  }

  void _disposeRive() {
    _stateInput?.dispose();
    _audioInput?.dispose();
    _stateInput = null;
    _audioInput = null;
    _riveController = null;
    _fileLoader?.dispose();
    _fileLoader = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeRive();
    super.dispose();
  }

  Widget _buildFallback() {
    return VisionAiOrb(
      size: widget.size,
      state: widget.state,
      audioLevel: widget.audioLevel,
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRiveAsset || _fileLoader == null) {
      return _buildFallback();
    }

    final config = widget.riveConfig!;
    final stateName = switch (widget.state) {
      VisionOrbState.idle => 'Ready',
      VisionOrbState.listening => 'Listening',
      VisionOrbState.thinking => 'Thinking',
      VisionOrbState.speaking => 'Speaking',
      VisionOrbState.error => 'Attention needed',
      VisionOrbState.offline => 'Offline',
    };

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RiveWidgetBuilder(
          fileLoader: _fileLoader!,
          artboardSelector: config.artboardName != null
              ? ArtboardSelector.byName(config.artboardName!)
              : const ArtboardDefault(),
          stateMachineSelector: StateMachineSelector.byName(
            config.stateMachineName,
          ),
          onLoaded: (loaded) => _bindRiveController(loaded.controller),
          onFailed: (_, _) {
            if (mounted && !_riveLoadFailed) {
              setState(() => _riveLoadFailed = true);
            }
          },
          builder: (context, riveState) {
            return switch (riveState) {
              RiveLoading() || RiveFailed() => _buildFallback(),
              RiveLoaded() => Semantics(
                button: widget.onTap != null,
                label: '${widget.semanticLabel}, state: $stateName',
                child: GestureDetector(
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: RiveWidget(
                    controller: riveState.controller,
                    fit: Fit.contain,
                  ),
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

/// Live Riverpod-connected [VisionOrb] that derives its state exclusively from
/// real voice capture, chat processing, TTS playback, error, and offline state.
class ConnectedVisionOrb extends ConsumerWidget {
  const ConnectedVisionOrb({
    super.key,
    this.size = AppConstants.orbBaseSize,
    this.isOffline = false,
    this.onTap,
    this.riveConfig,
  });

  final double size;
  final bool isOffline;
  final VoidCallback? onTap;
  final VisionOrbRiveConfig? riveConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceControllerProvider);
    final chat = ref.watch(chatControllerProvider);

    final isListening = voice.isMicActuallyActive;
    final isSpeaking = voice.isSpeaking;
    final isThinking = chat.isLoading;
    final hasError =
        voice.errorMessage != null && voice.errorMessage!.isNotEmpty;
    final effectiveOffline = isOffline || chat.isOfflineError;

    final resolvedState = VisionOrbStateResolver.resolve(
      isListening: isListening,
      isThinking: isThinking,
      isSpeaking: isSpeaking,
      hasError: hasError,
      isOffline: effectiveOffline,
    );

    return VisionOrb(
      size: size,
      state: resolvedState,
      audioLevel: isListening ? voice.normalizedAmplitude : 0.0,
      onTap: onTap,
      riveConfig: riveConfig,
    );
  }
}
