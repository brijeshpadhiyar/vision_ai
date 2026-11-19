import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';

/// Operational visual states of the animated [VisionAiOrb].
enum VisionOrbState { idle, listening, thinking, speaking, error, offline }

/// Premium multi-state animated AI orb powered by [CustomPainter] and isolated
/// inside a [RepaintBoundary] for sustained 60 FPS performance on Android.
class VisionAiOrb extends StatefulWidget {
  const VisionAiOrb({
    super.key,
    this.size = AppConstants.orbBaseSize,
    this.state = VisionOrbState.idle,
    this.audioLevel = 0.0,
    this.onTap,
    this.semanticLabel = 'VISION AI interactive orb',
  });

  final double size;
  final VisionOrbState state;

  /// Normalized microphone or playback amplitude in `[0.0, 1.0]`.
  final double audioLevel;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  State<VisionAiOrb> createState() => _VisionAiOrbState();
}

class _VisionAiOrbState extends State<VisionAiOrb>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _breathController;
  late final AnimationController _orbitController;
  late final AnimationController _waveController;
  double _smoothedLevel = 0.0;
  bool _reducedMotion = false;
  bool _tickerEnabled = true;
  bool _appPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _breathController = AnimationController(
      vsync: this,
      duration: VisionAnimations.orbBreath,
    );

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5400),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _syncAnimationPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (paused != _appPaused) {
      _appPaused = paused;
      _syncAnimationPlayback();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = VisionAnimations.isReducedMotion(context);
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (reduce != _reducedMotion || tickerEnabled != _tickerEnabled) {
      _reducedMotion = reduce;
      _tickerEnabled = tickerEnabled;
      _syncAnimationPlayback();
    }
  }

  @override
  void didUpdateWidget(covariant VisionAiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smoothly interpolate incoming audio amplitude for fluid ring expansion.
    final target = widget.audioLevel.clamp(0.0, 1.0);
    _smoothedLevel = (_smoothedLevel * 0.45) + (target * 0.55);

    if (oldWidget.state != widget.state) {
      _orbitController.duration = switch (widget.state) {
        VisionOrbState.idle => const Duration(milliseconds: 6800),
        VisionOrbState.listening => const Duration(milliseconds: 2800),
        VisionOrbState.thinking => const Duration(milliseconds: 1900),
        VisionOrbState.speaking => const Duration(milliseconds: 2400),
        VisionOrbState.error => const Duration(milliseconds: 4200),
        VisionOrbState.offline => const Duration(milliseconds: 9000),
      };
      _syncAnimationPlayback();
    }
  }

  void _syncAnimationPlayback() {
    final shouldPause =
        _reducedMotion ||
        !_tickerEnabled ||
        _appPaused ||
        widget.state == VisionOrbState.offline;

    if (shouldPause) {
      _breathController.stop();
      _orbitController.stop();
      _waveController.stop();
      _breathController.value = 0.5;
      _orbitController.value = 0.0;
      _waveController.value = 0.0;
    } else {
      if (!_breathController.isAnimating) {
        _breathController.repeat(reverse: true);
      }
      if (!_orbitController.isAnimating) {
        _orbitController.repeat();
      }
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breathController.dispose();
    _orbitController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final stateName = switch (widget.state) {
      VisionOrbState.idle => 'Ready',
      VisionOrbState.listening => 'Listening',
      VisionOrbState.thinking => 'Thinking',
      VisionOrbState.speaking => 'Speaking',
      VisionOrbState.error => 'Attention needed',
      VisionOrbState.offline => 'Offline',
    };

    final orb = RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _breathController,
            _orbitController,
            _waveController,
          ]),
          builder: (context, _) {
            return CustomPaint(
              painter: _VisionOrbPainter(
                orbState: widget.state,
                brightness: brightness,
                breath: Curves.easeInOutSine.transform(_breathController.value),
                orbit: _orbitController.value,
                wave: _waveController.value,
                audioLevel: _smoothedLevel,
                reducedMotion: _reducedMotion,
              ),
            );
          },
        ),
      ),
    );

    if (widget.onTap == null) {
      return Semantics(
        label: '${widget.semanticLabel}, state: $stateName',
        child: orb,
      );
    }

    return Semantics(
      button: true,
      label:
          '${widget.semanticLabel}, state: $stateName. Double tap to activate.',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: orb,
      ),
    );
  }
}

class _VisionOrbPainter extends CustomPainter {
  const _VisionOrbPainter({
    required this.orbState,
    required this.brightness,
    required this.breath,
    required this.orbit,
    required this.wave,
    required this.audioLevel,
    required this.reducedMotion,
  });

  final VisionOrbState orbState;
  final Brightness brightness;
  final double breath;
  final double orbit;
  final double wave;
  final double audioLevel;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);
    final isDark = brightness == Brightness.dark;

    // Midnight Violet + Pearl Lavender state palettes
    final (
      Color primary,
      Color secondary,
      Color highlight,
    ) = switch (orbState) {
      VisionOrbState.idle => (
        VisionColors.primaryAccent(brightness),
        VisionColors.tertiaryAccent(brightness),
        VisionColors.accentIce,
      ),
      VisionOrbState.listening => (
        VisionColors.secondaryAccent(brightness),
        VisionColors.primaryAccent(brightness),
        VisionColors.darkSecondary,
      ),
      VisionOrbState.thinking => (
        VisionColors.primaryAccent(brightness),
        VisionColors.tertiaryAccent(brightness),
        VisionColors.secondaryAccent(brightness),
      ),
      VisionOrbState.speaking => (
        VisionColors.primaryAccent(brightness),
        VisionColors.secondaryAccent(brightness),
        VisionColors.accentIce,
      ),
      VisionOrbState.error => (
        VisionColors.semanticError(brightness),
        VisionColors.semanticWarning(brightness),
        VisionColors.darkTertiary,
      ),
      VisionOrbState.offline => (
        VisionColors.mutedText(brightness),
        VisionColors.borderColor(brightness),
        VisionColors.secondaryText(brightness),
      ),
    };

    // Subtle vertical float in idle/listening
    final floatY = reducedMotion
        ? 0.0
        : math.sin(orbit * math.pi * 2) *
              (orbState == VisionOrbState.idle
                  ? minDim * 0.015
                  : minDim * 0.01);
    final orbCenter = Offset(center.dx, center.dy + floatY);

    final baseRadius = minDim * 0.30;
    final audioBoost = switch (orbState) {
      VisionOrbState.listening => audioLevel * 0.16,
      VisionOrbState.speaking =>
        0.04 + (math.sin(wave * math.pi * 2).abs() * 0.08) + audioLevel * 0.12,
      VisionOrbState.thinking => 0.03 * math.sin(wave * math.pi * 2),
      VisionOrbState.error => 0.02 * math.sin(wave * math.pi * 4),
      VisionOrbState.idle || VisionOrbState.offline => 0.0,
    };

    final coreRadius = baseRadius * (0.94 + breath * 0.07 + audioBoost);

    // 1. Atmospheric radial aura (hardware-accelerated gradient, no MaskFilter)
    final auraRadius = minDim * (0.50 + audioBoost * 0.25);
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: (isDark ? 0.32 : 0.22) + audioBoost * 0.3),
          secondary.withValues(alpha: isDark ? 0.14 : 0.08),
          Colors.transparent,
        ],
        stops: const [0.15, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: auraRadius));
    canvas.drawCircle(orbCenter, auraRadius, auraPaint);

    // 2. Listening / Speaking expanding pulse rings
    if (orbState == VisionOrbState.listening ||
        orbState == VisionOrbState.speaking) {
      const ringCount = 2;
      for (int i = 0; i < ringCount; i++) {
        final phase = (wave + i / ringCount) % 1.0;
        final ringRadius =
            coreRadius * (1.12 + phase * (0.52 + audioLevel * 0.25));
        final ringAlpha = (1.0 - phase) * (0.48 + audioLevel * 0.3);
        canvas.drawCircle(
          orbCenter,
          ringRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = primary.withValues(alpha: ringAlpha.clamp(0.0, 0.85)),
        );
      }
    }

    // 3. Outer glass orbital bezel
    final bezelRadius = minDim * 0.40;
    canvas.drawCircle(
      orbCenter,
      bezelRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = orbState == VisionOrbState.error ? 1.8 : 1.2
        ..color = primary.withValues(
          alpha: orbState == VisionOrbState.idle ? 0.24 : 0.45,
        ),
    );

    // 4. Audio-reactive harmonic waveform ring (Listening & Speaking)
    if (orbState == VisionOrbState.listening ||
        orbState == VisionOrbState.speaking) {
      _drawWaveformRing(
        canvas: canvas,
        center: orbCenter,
        radius: bezelRadius * 0.96,
        color: highlight,
        amplitude: orbState == VisionOrbState.listening
            ? (0.18 + audioLevel * 0.82)
            : (0.35 + audioLevel * 0.65),
        phase: wave * math.pi * 2,
        barCount: 36,
        maxBarHeight: minDim * 0.055,
      );
    }

    // 5. Thinking orbital arc & light particles (kept <= 6 particles for 60fps)
    if (orbState == VisionOrbState.thinking) {
      final arcRect = Rect.fromCircle(center: orbCenter, radius: bezelRadius);
      final startAngle = orbit * math.pi * 2;
      canvas.drawArc(
        arcRect,
        startAngle,
        math.pi * 0.85,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.6
          ..shader = SweepGradient(
            startAngle: startAngle,
            endAngle: startAngle + math.pi * 0.85,
            colors: [Colors.transparent, primary, highlight],
          ).createShader(arcRect),
      );

      const particleCount = 6;
      for (int i = 0; i < particleCount; i++) {
        final angle = startAngle + (i * (math.pi * 2 / particleCount));
        final orbitR =
            bezelRadius * (0.86 + 0.14 * math.sin(wave * math.pi * 2 + i));
        final pos = Offset(
          orbCenter.dx + math.cos(angle) * orbitR,
          orbCenter.dy + math.sin(angle) * orbitR,
        );
        final dotR = i.isEven ? 3.2 : 2.1;
        canvas.drawCircle(
          pos,
          dotR,
          Paint()
            ..color = (i.isEven ? highlight : primary).withValues(alpha: 0.9),
        );
      }
    }

    // 6. Core rotating liquid sphere
    final angle = orbit * math.pi * 2;
    final gradCenter = Alignment(
      math.cos(angle) * 0.35,
      math.sin(angle) * 0.35 - 0.12,
    );
    final coreRect = Rect.fromCircle(center: orbCenter, radius: coreRadius);
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: gradCenter,
        radius: 0.95,
        colors: [
          highlight,
          primary,
          secondary,
          VisionColors.accentDeep.withValues(alpha: isDark ? 0.95 : 0.85),
        ],
        stops: const [0.0, 0.34, 0.72, 1.0],
      ).createShader(coreRect);
    canvas.drawCircle(orbCenter, coreRadius, corePaint);

    // 7. Inner specular glass rim & crescent highlight
    canvas.drawCircle(
      orbCenter,
      coreRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.72),
            Colors.white.withValues(alpha: 0.10),
            primary.withValues(alpha: 0.45),
          ],
        ).createShader(coreRect),
    );

    // Soft glass reflection highlight on upper-left quadrant
    final specRect = Rect.fromCenter(
      center: Offset(
        orbCenter.dx - coreRadius * 0.28,
        orbCenter.dy - coreRadius * 0.32,
      ),
      width: coreRadius * 0.52,
      height: coreRadius * 0.26,
    );
    canvas.save();
    canvas.translate(specRect.center.dx, specRect.center.dy);
    canvas.rotate(-0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: specRect.width,
        height: specRect.height,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
    canvas.restore();
  }

  void _drawWaveformRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
    required double amplitude,
    required double phase,
    required int barCount,
    required double maxBarHeight,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.78)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final theta = (i / barCount) * math.pi * 2;
      final harmonic =
          0.35 +
          0.65 *
              ((math.sin(theta * 3 + phase) + math.cos(theta * 5 - phase * 1.4))
                      .abs() /
                  2.0);
      final barLen = maxBarHeight * amplitude * harmonic;
      final inner = Offset(
        center.dx + math.cos(theta) * (radius - barLen * 0.2),
        center.dy + math.sin(theta) * (radius - barLen * 0.2),
      );
      final outer = Offset(
        center.dx + math.cos(theta) * (radius + barLen),
        center.dy + math.sin(theta) * (radius + barLen),
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisionOrbPainter oldDelegate) {
    return oldDelegate.orbState != orbState ||
        oldDelegate.brightness != brightness ||
        oldDelegate.breath != breath ||
        oldDelegate.orbit != orbit ||
        oldDelegate.wave != wave ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}
