import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Result from an offline Developer Assistant utility operation.
@immutable
class DevToolResult {
  const DevToolResult({required this.success, required this.output});

  final bool success;
  final String output;
}

/// 100% offline developer utility engine for Module 26 (Developer Assistant).
abstract final class DeveloperToolsService {
  /// Pretty-prints and validates JSON input.
  static DevToolResult formatJson(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const DevToolResult(success: false, output: 'Enter JSON to format.');
    }
    try {
      final decoded = jsonDecode(trimmed);
      const encoder = JsonEncoder.withIndent('  ');
      return DevToolResult(success: true, output: encoder.convert(decoded));
    } on FormatException catch (e) {
      return DevToolResult(
        success: false,
        output: 'Invalid JSON: ${e.message}',
      );
    }
  }

  /// Encodes UTF-8 text to Base64.
  static DevToolResult encodeBase64(String input) {
    return DevToolResult(
      success: true,
      output: base64Encode(utf8.encode(input)),
    );
  }

  /// Decodes Base64 (standard or URL-safe) to UTF-8 text.
  static DevToolResult decodeBase64(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const DevToolResult(
        success: false,
        output: 'Enter Base64 text to decode.',
      );
    }
    try {
      final normalized = base64.normalize(trimmed);
      final bytes = base64Decode(normalized);
      return DevToolResult(success: true, output: utf8.decode(bytes));
    } catch (e) {
      return DevToolResult(
        success: false,
        output: 'Invalid Base64: $e',
      );
    }
  }

  /// Decodes JWT header and payload locally (never transmits tokens).
  static DevToolResult decodeJwt(String token) {
    final parts = token.trim().split('.');
    if (parts.length < 2) {
      return const DevToolResult(
        success: false,
        output: 'Invalid JWT: expected header.payload.signature format.',
      );
    }
    try {
      String decodePart(String part) {
        final normalized = base64Url.normalize(part);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final parsed = jsonDecode(decoded);
        return const JsonEncoder.withIndent('  ').convert(parsed);
      }

      final header = decodePart(parts[0]);
      final payload = decodePart(parts[1]);
      return DevToolResult(
        success: true,
        output: 'HEADER:\n$header\n\nPAYLOAD:\n$payload',
      );
    } catch (e) {
      return DevToolResult(
        success: false,
        output: 'Unable to decode JWT: $e',
      );
    }
  }

  /// Evaluates a regular expression [pattern] against [sampleText].
  static DevToolResult testRegex({
    required String pattern,
    required String sampleText,
    bool caseSensitive = true,
  }) {
    if (pattern.isEmpty) {
      return const DevToolResult(
        success: false,
        output: 'Enter a regular expression pattern.',
      );
    }
    try {
      final regex = RegExp(pattern, caseSensitive: caseSensitive);
      final matches = regex.allMatches(sampleText).toList(growable: false);
      if (matches.isEmpty) {
        return const DevToolResult(success: true, output: '0 matches found.');
      }
      final buffer = StringBuffer('${matches.length} match(es) found:\n');
      for (var i = 0; i < matches.length; i++) {
        final m = matches[i];
        buffer.writeln('[${i + 1}] "${m.group(0)}" (index ${m.start}..${m.end})');
      }
      return DevToolResult(success: true, output: buffer.toString().trim());
    } on FormatException catch (e) {
      return DevToolResult(
        success: false,
        output: 'Invalid RegExp: ${e.message}',
      );
    }
  }
}
