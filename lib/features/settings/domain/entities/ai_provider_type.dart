/// Supported AI provider backends in VISION AI.
enum AiProviderType {
  gemini(
    id: 'gemini',
    displayName: 'Google Gemini',
    defaultModel: 'gemini-3.5-flash-lite',
    keyHint: 'AIza...',
    summary: 'Gemini 3.5 Flash-Lite / 3.8 Flash • Multimodal & fast assistant',
  ),
  openAi(
    id: 'openai',
    displayName: 'OpenAI',
    defaultModel: 'gpt-5.4-mini',
    keyHint: 'sk-...',
    summary: 'GPT-5.4 Mini / GPT-5.4 • Responses API & tool calling',
  ),
  claude(
    id: 'claude',
    displayName: 'Anthropic Claude',
    defaultModel: 'claude-haiku-5-5',
    keyHint: 'sk-ant-...',
    summary: 'Claude 5.5 Haiku / Sonnet • Nuanced reasoning & tool use',
  );

  const AiProviderType({
    required this.id,
    required this.displayName,
    required this.defaultModel,
    required this.keyHint,
    required this.summary,
  });

  /// Stable persistence identifier.
  final String id;

  /// Human-readable provider name.
  final String displayName;

  /// Default production model identifier used when no custom model is chosen.
  final String defaultModel;

  /// Placeholder hint illustrating expected API key prefix.
  final String keyHint;

  /// Short description shown in Settings.
  final String summary;

  /// Resolves an [AiProviderType] from its persisted [id], defaulting to [gemini].
  static AiProviderType fromId(String? id) {
    for (final provider in AiProviderType.values) {
      if (provider.id == id) {
        return provider;
      }
    }
    return AiProviderType.gemini;
  }
}
