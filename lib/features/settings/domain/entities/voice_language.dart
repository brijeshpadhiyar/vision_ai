/// Supported voice and conversational languages for VISION AI (Module 05).
enum VoiceLanguage {
  auto(
    id: 'auto',
    displayName: 'Auto',
    nativeName: 'Auto (EN / HI / GU)',
    localeCode: 'en-IN',
  ),
  english(
    id: 'english',
    displayName: 'English',
    nativeName: 'English (India)',
    localeCode: 'en-IN',
  ),
  hindi(
    id: 'hindi',
    displayName: 'Hindi',
    nativeName: 'हिन्दी (Hindi)',
    localeCode: 'hi-IN',
  ),
  gujarati(
    id: 'gujarati',
    displayName: 'Gujarati',
    nativeName: 'ગુજરાતી (Gujarati)',
    localeCode: 'gu-IN',
  );

  const VoiceLanguage({
    required this.id,
    required this.displayName,
    required this.nativeName,
    required this.localeCode,
  });

  /// Stable persistence identifier.
  final String id;

  /// English display name.
  final String displayName;

  /// Localized script label.
  final String nativeName;

  /// Standard BCP-47 locale tag.
  final String localeCode;

  /// Resolves a [VoiceLanguage] from its persisted [id], defaulting to [english].
  static VoiceLanguage fromId(String? id) {
    for (final language in VoiceLanguage.values) {
      if (language.id == id) {
        return language;
      }
    }
    return VoiceLanguage.english;
  }
}
