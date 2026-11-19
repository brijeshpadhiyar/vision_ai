import 'package:flutter/foundation.dart';

/// A single live web source returned by [InternetResearchService] (Module 21).
@immutable
class ResearchSource {
  const ResearchSource({
    required this.title,
    required this.url,
    required this.snippet,
    this.domain = '',
  });

  factory ResearchSource.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] as String?) ?? '';
    return ResearchSource(
      title: (json['title'] as String?) ?? 'Source',
      url: url,
      snippet: (json['snippet'] as String?) ?? '',
      domain: (json['domain'] as String?) ?? extractDomain(url),
    );
  }

  final String title;
  final String url;
  final String snippet;
  final String domain;

  String get resolvedDomain => domain.isNotEmpty ? domain : extractDomain(url);

  static String extractDomain(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'url': url,
    'snippet': snippet,
    'domain': resolvedDomain,
  };
}

/// Aggregated web research results injected into an AI completion prompt.
@immutable
class ResearchBundle {
  const ResearchBundle({
    required this.query,
    required this.sources,
    required this.fetchedAt,
  });

  final String query;
  final List<ResearchSource> sources;
  final DateTime fetchedAt;

  bool get hasSources => sources.isNotEmpty;

  /// Formats numbered sources for grounded synthesis with inline `[1]`, `[2]` citations.
  String buildPromptContext() {
    if (sources.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln('LIVE WEB RESEARCH SOURCES (query: "$query"):');
    for (var i = 0; i < sources.length; i++) {
      final src = sources[i];
      buffer.writeln(
        '[${i + 1}] ${src.title} (${src.resolvedDomain}) — ${src.url}\n'
        '    ${src.snippet}',
      );
    }
    buffer.writeln(
      'Use these live sources to answer accurately, cite relevant sources inline '
      'as [1], [2], etc., and never fabricate URLs or unverified facts.',
    );
    return buffer.toString().trim();
  }
}
