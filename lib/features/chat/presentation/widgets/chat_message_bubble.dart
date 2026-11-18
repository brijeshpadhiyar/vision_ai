import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';

/// Displays an individual user or VISION assistant message bubble.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    super.key,
    this.onSpeak,
    this.isSpeaking = false,
  });

  final ChatMessage message;
  final VoidCallback? onSpeak;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.sender == MessageSender.user;
    final modelSuffix =
        !isUser && message.modelId != null && message.modelId!.isNotEmpty
        ? ' (${message.modelId})'
        : '';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser
                ? colorScheme.primary.withValues(alpha: 0.16)
                : colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: Border.all(
              color: isUser
                  ? colorScheme.primary.withValues(alpha: 0.45)
                  : colorScheme.outline,
            ),
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
                    color: isUser ? colorScheme.primary : AppColors.cyanAccent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isUser
                          ? 'You'
                          : 'VISION • ${message.provider?.displayName ?? 'AI'}$modelSuffix',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!isUser) ...[
                    if (onSpeak != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onSpeak,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            isSpeaking
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_outlined,
                            size: 15,
                            color: isSpeaking
                                ? AppColors.warning
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    InkWell(
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
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (!isUser && message.routingNotice != null) ...[
                const SizedBox(height: 4),
                Text(
                  message.routingNotice!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              SelectableText(
                message.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              if (!isUser &&
                  (message.inputTokens != null ||
                      message.outputTokens != null)) ...[
                const SizedBox(height: 6),
                Text(
                  'Tokens: in ${message.inputTokens ?? '-'} • out ${message.outputTokens ?? '-'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
