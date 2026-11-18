import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/error_handler.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Liquid Glass modal dialog allowing secure entry or removal of an API key.
class ApiKeyConfigDialog extends StatefulWidget {
  const ApiKeyConfigDialog({
    required this.provider,
    required this.hasExistingKey,
    required this.onSave,
    required this.onRemove,
    super.key,
  });

  final AiProviderType provider;
  final bool hasExistingKey;
  final Future<void> Function(String apiKey) onSave;
  final Future<void> Function() onRemove;

  @override
  State<ApiKeyConfigDialog> createState() => _ApiKeyConfigDialogState();
}

class _ApiKeyConfigDialogState extends State<ApiKeyConfigDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscureText = true;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = 'Please enter a valid API key.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.onSave(trimmed);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = SecretRedactor.redact(
            AppErrorHandler.toUserMessage(error),
          );
        });
      }
    }
  }

  Future<void> _handleRemove() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await widget.onRemove();
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = SecretRedactor.redact(
            AppErrorHandler.toUserMessage(error),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VisionGlassDialog(
      title: '${widget.provider.displayName} Key',
      icon: Icons.key_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your API key is encrypted and stored locally in Android Keystore. '
            'It is never logged, backed up, or shared.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          VisionGlassInput(
            controller: _controller,
            obscureText: _obscureText,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_isSaving,
            labelText: 'API Key (${widget.provider.keyHint})',
            errorText: _errorText,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureText = !_obscureText),
              icon: Icon(
                _obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              tooltip: _obscureText ? 'Show API key' : 'Hide API key',
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hasExistingKey)
          TextButton(
            onPressed: _isSaving ? null : _handleRemove,
            style: TextButton.styleFrom(foregroundColor: VisionColors.error),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        VisionGlassButton(
          label: 'Save Key',
          compact: true,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }
}
