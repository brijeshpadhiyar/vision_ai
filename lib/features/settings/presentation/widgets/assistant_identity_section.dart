import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/features/settings/domain/entities/assistant_identity.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_tile.dart';

/// Settings section for Module 01 (Assistant Identity): personality preset,
/// communication style, custom greeting, and custom behaviour instructions.
class AssistantIdentitySection extends StatelessWidget {
  const AssistantIdentitySection({
    super.key,
    required this.identity,
    required this.onIdentityChanged,
  });

  final AssistantIdentity identity;
  final ValueChanged<AssistantIdentity> onIdentityChanged;

  Future<void> _openTextEditor(
    BuildContext context, {
    required String title,
    required String hint,
    required String initialValue,
    required int maxLines,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: maxLines,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Reset'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) {
      onSave(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SettingsSectionCard(
      title: 'Assistant Identity',
      icon: Icons.auto_awesome_outlined,
      subtitle: 'Customize VISION\'s personality, greeting, communication style, and behaviour',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personality Preset',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: VisionColors.primaryText(brightness)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in AssistantPersonality.values)
                    VisionGlassChip(
                      label: preset.displayName,
                      selected: identity.personality == preset,
                      onTap: () => onIdentityChanged(
                        identity.copyWith(personality: preset),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Communication Style',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: VisionColors.primaryText(brightness)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final style in CommunicationStyle.values)
                    VisionGlassChip(
                      label: style.displayName,
                      selected: identity.communicationStyle == style,
                      onTap: () => onIdentityChanged(
                        identity.copyWith(communicationStyle: style),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SettingsTile(
          icon: Icons.waving_hand_outlined,
          title: 'Custom Home Greeting',
          subtitle: identity.customGreeting.trim().isEmpty
              ? 'Default (${identity.effectiveGreeting})'
              : identity.customGreeting.trim(),
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: () => _openTextEditor(
            context,
            title: 'Custom Home Greeting',
            hint: 'e.g., Welcome back, Brijesh',
            initialValue: identity.customGreeting,
            maxLines: 1,
            onSave: (val) =>
                onIdentityChanged(identity.copyWith(customGreeting: val)),
          ),
        ),
        SettingsTile(
          icon: Icons.tune_rounded,
          title: 'Custom Behaviour Instructions',
          subtitle: identity.customInstructions.trim().isEmpty
              ? 'None • Add optional rules injected into VISION\'s system prompt'
              : identity.customInstructions.trim(),
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: () => _openTextEditor(
            context,
            title: 'Custom Behaviour Instructions',
            hint: 'e.g., Keep answers voice-friendly and prefer Indian units.',
            initialValue: identity.customInstructions,
            maxLines: 4,
            onSave: (val) =>
                onIdentityChanged(identity.copyWith(customInstructions: val)),
          ),
        ),
      ],
    );
  }
}
