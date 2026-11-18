import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/presentation/widgets/vision_markdown_text.dart';

/// Liquid Glass message bubble for user prompts and Markdown-rendered AI replies.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    super.key,
    this.onSpeak,
    this.onRegenerate,
    this.isSpeaking = false,
    this.isStreaming = false,
  });

  final ChatMessage message;
  final VoidCallback? onSpeak;
  final VoidCallback? onRegenerate;
  final bool isSpeaking;
  final bool isStreaming;

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);
    final isUser = message.sender == MessageSender.user;
    final modelSuffix =
        !isUser && message.modelId != null && message.modelId!.isNotEmpty
        ? ' • ${message.modelId}'
        : '';

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(VisionRadii.lg),
      topRight: const Radius.circular(VisionRadii.lg),
      bottomLeft: Radius.circular(isUser ? VisionRadii.lg : VisionRadii.xs),
      bottomRight: Radius.circular(isUser ? VisionRadii.xs : VisionRadii.lg),
    );

    final bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 10),
          decoration: VisionGlass.decoration(
            brightness,
            variant: isUser
                ? VisionGlassVariant.accent
                : VisionGlassVariant.standard,
            borderRadius: radius,
            borderColor: message.isError
                ? VisionColors.error.withValues(alpha: 0.6)
                : isUser
                ? accent.withValues(alpha: 0.48)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser
                        ? Icons.person_outline_rounded
                        : Icons.auto_awesome_rounded,
                    size: 14,
                    color: isUser ? accent : VisionColors.accentPrimary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isUser
                          ? 'You'
                          : 'VISION • ${message.provider?.displayName ?? 'AI'}$modelSuffix',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimestamp(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: VisionColors.mutedText(brightness),
                    ),
                  ),
                ],
              ),
              if (!isUser && message.routingNotice != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: VisionRadii.xsBorder,
                    color: VisionColors.warning.withValues(alpha: 0.14),
                    border: Border.all(
                      color: VisionColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    message.routingNotice!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: VisionColors.warning,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (isUser)
                SelectableText(
                  message.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    color: VisionColors.primaryText(brightness),
                  ),
                )
              else
                VisionMarkdownText(
                  data: message.content,
                  isStreaming: isStreaming,
                ),
              if (!isUser) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (message.inputTokens != null ||
                        message.outputTokens != null)
                      Expanded(
                        child: Text(
                          'Tokens: in ${message.inputTokens ?? '-'} • out ${message.outputTokens ?? '-'}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: VisionColors.mutedText(brightness),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (onSpeak != null)
                      _BubbleActionButton(
                        icon: isSpeaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        tooltip: isSpeaking ? 'Stop speaking' : 'Read aloud',
                        color: isSpeaking
                            ? VisionColors.warning
                            : VisionColors.secondaryText(brightness),
                        onTap: onSpeak!,
                      ),
                    _BubbleActionButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Copy response',
                      color: VisionColors.secondaryText(brightness),
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: message.content),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reply copied to clipboard.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    if (onRegenerate != null)
                      _BubbleActionButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Regenerate response',
                        color: accent,
                        onTap: onRegenerate!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (VisionAnimations.isReducedMotion(context)) {
      return bubble;
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(message.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: VisionAnimations.standardFast,
      curve: VisionAnimations.standardCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      child: bubble,
    );
  }
}

class _BubbleActionButton extends StatelessWidget {
  const _BubbleActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: VisionRadii.smBorder,
          child: SizedBox(
            width: 38,
            height: 36,
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}
