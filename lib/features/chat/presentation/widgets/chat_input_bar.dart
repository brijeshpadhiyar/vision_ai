import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_button.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_container.dart';
import 'package:vision_ai/features/chat/domain/entities/image_attachment.dart';

/// Floating Liquid Glass message composer bar for the VISION chat screen.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.providerName,
    super.key,
    this.isListening = false,
    this.webResearchEnabled = false,
    this.pendingImage,
    this.onVoiceTap,
    this.onCameraTap,
    this.onGalleryTap,
    this.onClearImage,
    this.onExtractOcr,
    this.onToggleWebResearch,
    this.onCancel,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final String providerName;
  final bool isListening;
  final bool webResearchEnabled;
  final ImageAttachment? pendingImage;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onCameraTap;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onClearImage;
  final VoidCallback? onExtractOcr;
  final VoidCallback? onToggleWebResearch;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return VisionGlassContainer(
      variant: VisionGlassVariant.elevated,
      blurSigma: VisionGlass.blurSoft,
      borderRadius: VisionRadii.xlBorder,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      showShadow: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingImage != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: VisionRadii.smBorder,
                    child: Image.memory(
                      pendingImage!.decodeBytes(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pendingImage!.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (onExtractOcr != null)
                    TextButton.icon(
                      onPressed: isLoading ? null : onExtractOcr,
                      icon: const Icon(Icons.document_scanner_outlined, size: 16),
                      label: const Text('Read Text (OCR)'),
                    ),
                  if (onClearImage != null)
                    IconButton(
                      tooltip: 'Remove photo',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: isLoading ? null : onClearImage,
                    ),
                ],
              ),
            ),
          ],
          if (onCameraTap != null ||
              onGalleryTap != null ||
              onToggleWebResearch != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(
                children: [
                  if (onCameraTap != null)
                    IconButton(
                      tooltip: 'Capture photo with camera',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.photo_camera_outlined,
                        size: 20,
                        color: VisionColors.secondaryText(brightness),
                      ),
                      onPressed: isLoading ? null : onCameraTap,
                    ),
                  if (onGalleryTap != null)
                    IconButton(
                      tooltip: 'Pick photo from gallery',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.photo_library_outlined,
                        size: 20,
                        color: VisionColors.secondaryText(brightness),
                      ),
                      onPressed: isLoading ? null : onGalleryTap,
                    ),
                  if (onToggleWebResearch != null)
                    FilterChip(
                      label: const Text('Web'),
                      avatar: Icon(
                        Icons.public_rounded,
                        size: 16,
                        color: webResearchEnabled
                            ? VisionColors.primaryAccent(brightness)
                            : VisionColors.secondaryText(brightness),
                      ),
                      selected: webResearchEnabled,
                      visualDensity: VisualDensity.compact,
                      onSelected: isLoading ? null : (_) => onToggleWebResearch!(),
                    ),
                ],
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
          if (onVoiceTap != null) ...[
            VisionGlassIconButton(
              icon: isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
              tooltip: isListening ? 'Stop voice input' : 'Speak prompt',
              iconColor: isListening
                  ? VisionColors.success
                  : VisionColors.primaryAccent(brightness),
              glowColor: VisionColors.success,
              isActive: isListening,
              onPressed: isLoading ? null : onVoiceTap,
            ),
            const SizedBox(width: 6),
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
                    : 'Ask $providerName...',
                hintStyle: theme.textTheme.bodyMedium,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: isLoading
                ? 'Stop AI response generation'
                : 'Send message to VISION',
            child: Tooltip(
              message: isLoading ? 'Stop generation' : 'Send',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? onCancel : onSend,
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: VisionAnimations.resolveDuration(
                      context,
                      VisionAnimations.micro,
                    ),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isLoading
                            ? [VisionColors.warning, VisionColors.error]
                            : [
                                VisionColors.accentPrimary,
                                VisionColors.accentSecondary,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isLoading
                                      ? VisionColors.error
                                      : VisionColors.accentPrimary)
                                  .withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isLoading
                            ? Icons.stop_rounded
                            : Icons.arrow_upward_rounded,
                        size: 22,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? VisionColors.backgroundPrimary
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}
