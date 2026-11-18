/// Scrubs API keys, bearer tokens, and authorization secrets from logs and error strings.
abstract final class SecretRedactor {
  static final List<RegExp> _secretPatterns = <RegExp>[
    RegExp(r'AIza[0-9A-Za-z\-_]{16,}'),
    RegExp(r'sk-ant-[0-9A-Za-z\-_]{12,}'),
    RegExp(r'sk-(?:proj-|svcacct-|live-|test-)?[0-9A-Za-z\-_]{12,}'),
    RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    RegExp(r'([?&]key=)[^&\s]+', caseSensitive: false),
  ];

  /// Returns [input] with any recognized secret tokens replaced by `[REDACTED]`.
  static String redact(String input) {
    if (input.isEmpty) return input;
    var sanitized = input;
    for (var i = 0; i < _secretPatterns.length; i++) {
      final pattern = _secretPatterns[i];
      if (i >= 3) {
        sanitized = sanitized.replaceAllMapped(
          pattern,
          (match) => '${match.group(1) ?? ''}[REDACTED]',
        );
      } else {
        sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
      }
    }
    return sanitized;
  }
}
