import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/error_handler.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Modal dialog allowing the user to securely enter or clear an AI provider API key.
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
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outline),
      ),
      title: Row(
        children: [
          Icon(Icons.key_rounded, color: colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.provider.displayName} Key',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your API key is encrypted and stored locally in the Android Keystore. '
            'It is never logged or shared.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_isSaving,
            decoration: InputDecoration(
              labelText: 'API Key (${widget.provider.keyHint})',
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscureText ? 'Show API key' : 'Hide API key',
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hasExistingKey)
          TextButton(
            onPressed: _isSaving ? null : _handleRemove,
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Remove Key'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Key'),
        ),
      ],
    );
  }
}
