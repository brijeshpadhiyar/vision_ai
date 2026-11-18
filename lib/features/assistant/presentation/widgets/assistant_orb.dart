import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/constants/app_constants.dart';

/// Central glowing orb representing VISION's presence and live voice activity.
class AssistantOrb extends StatefulWidget {
  const AssistantOrb({
    super.key,
    this.size = AppConstants.orbBaseSize,
    this.isHighlighted = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.audioLevel = 0.0,
  });

  final double size;
  final bool isHighlighted;
  final bool isListening;
  final bool isSpeaking;
  final double audioLevel;

  @override
  State<AssistantOrb> createState() => _AssistantOrbState();
}

class _AssistantOrbState extends State<AssistantOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.orbPulseDuration,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _glowAnimation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerSize = widget.size;
    final coreSize = outerSize * 0.64;
    final activeBoost = widget.audioLevel.clamp(0.0, 1.0) * 0.18;
    final activeColor = widget.isListening
        ? AppColors.success
        : AppColors.cyanAccent;

    return Semantics(
      label: 'VISION central assistant orb',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulseScale = _scaleAnimation.value + activeBoost;
          final glowIntensity = (_glowAnimation.value + activeBoost).clamp(
            0.35,
            1.0,
          );

          return SizedBox(
            width: outerSize,
            height: outerSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ambient halo ring
                Transform.scale(
                  scale: pulseScale,
                  child: Container(
                    width: outerSize,
                    height: outerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          activeColor.withValues(alpha: 0.25 * glowIntensity),
                          AppColors.electricBlue.withValues(
                            alpha: 0.14 * glowIntensity,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),
                // Concentric orbital ring
                Container(
                  width: outerSize * 0.82,
                  height: outerSize * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeColor.withValues(
                        alpha:
                            (widget.isHighlighted ||
                                widget.isListening ||
                                widget.isSpeaking)
                            ? 0.65
                            : 0.28,
                      ),
                      width: (widget.isListening || widget.isSpeaking)
                          ? 2.0
                          : 1.4,
                    ),
                  ),
                ),
                // Inner luminous core
                Transform.scale(
                  scale: 0.96 + (pulseScale - 0.94) * 0.45,
                  child: Container(
                    width: coreSize,
                    height: coreSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.2, -0.25),
                        radius: 0.85,
                        colors: [
                          const Color(0xFF80F8FF),
                          activeColor,
                          AppColors.electricBlue,
                          AppColors.deepIndigo,
                        ],
                        stops: const [0.0, 0.35, 0.72, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(
                            alpha: 0.45 * glowIntensity,
                          ),
                          blurRadius: 34,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: AppColors.electricBlue.withValues(
                            alpha: 0.28 * glowIntensity,
                          ),
                          blurRadius: 56,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.isListening
                            ? Icons.graphic_eq_rounded
                            : widget.isSpeaking
                            ? Icons.volume_up_rounded
                            : Icons.auto_awesome_rounded,
                        color: AppColors.darkBackground,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
