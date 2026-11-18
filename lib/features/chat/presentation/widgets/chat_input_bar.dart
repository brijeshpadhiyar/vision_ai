import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';

/// Bottom message composer bar for the VISION conversation screen.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.providerName,
    super.key,
    this.isListening = false,
    this.onVoiceTap,
    this.onCancel,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final String providerName;
  final bool isListening;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onVoiceTap != null) ...[
            IconButton.outlined(
              onPressed: isLoading ? null : onVoiceTap,
              tooltip: isListening ? 'Stop voice input' : 'Speak prompt',
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: isListening ? AppColors.success : colorScheme.outline,
                ),
              ),
              icon: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: isListening ? AppColors.success : colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: isListening
                    ? 'Listening for voice prompt...'
                    : 'Ask VISION ($providerName)...',
                hintStyle: theme.textTheme.bodyMedium,
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: isLoading
                ? 'Cancel active AI request'
                : 'Send message to VISION',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading ? onCancel : onSend,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLoading
                          ? [AppColors.warning, AppColors.error]
                          : [AppColors.cyanAccent, AppColors.electricBlue],
                    ),
                  ),
                  child: Center(
                    child: isLoading
                        ? const Icon(
                            Icons.stop_rounded,
                            size: 22,
                            color: AppColors.darkBackground,
                          )
                        : const Icon(
                            Icons.send_rounded,
                            size: 22,
                            color: AppColors.darkBackground,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
