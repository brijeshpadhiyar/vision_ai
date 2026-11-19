import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:vision_ai/core/utils/http_client_provider.dart';
import 'package:vision_ai/features/research/domain/entities/research_source.dart';

/// Provides [InternetResearchService] for Module 21 (Zero-Config Internet Research).
final internetResearchServiceProvider = Provider<InternetResearchService>((
  ref,
) {
  final client = ref.watch(httpClientProvider);
  return InternetResearchService(client);
});

/// Zero-config live web research service querying DuckDuckGo Instant Answer
/// and Wikipedia APIs with deduplication and strict timeouts.
class InternetResearchService {
  const InternetResearchService(this._client);

  final http.Client _client;

  static final RegExp _explicitResearchPattern = RegExp(
    r'^(?:please\s+)?(?:research|search\s+the\s+web(?:\s+for)?|web\s+search(?:\s+for)?|look\s+up\s+online|latest\s+news\s+(?:about|on)|find\s+online)\b',
    caseSensitive: false,
  );

  /// Returns true when the user explicitly requests live web research by voice or text.
  static bool shouldAutoTriggerResearch(String prompt) {
    return _explicitResearchPattern.hasMatch(prompt.trim());
  }

  /// Strips leading research trigger verbs so the search query stays focused.
  static String normalizeQuery(String prompt) {
    final cleaned = prompt
        .trim()
        .replaceFirst(_explicitResearchPattern, '')
        .replaceFirst(RegExp(r'^[:\-\s]+'), '')
        .trim();
    return cleaned.isEmpty ? prompt.trim() : cleaned;
  }

  /// Fetches up to [maxSources] deduplicated live web sources for [rawQuery].
  Future<ResearchBundle> search(
    String rawQuery, {
    int maxSources = 5,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final query = normalizeQuery(rawQuery);
    if (query.isEmpty) {
      return ResearchBundle(
        query: rawQuery,
        sources: const <ResearchSource>[],
        fetchedAt: DateTime.now(),
      );
    }

    final results = await Future.wait<List<ResearchSource>>(<Future<List<ResearchSource>>>[
      _queryDuckDuckGo(query, timeout: timeout),
      _queryWikipedia(query, timeout: timeout),
    ]);

    final seenUrls = <String>{};
    final merged = <ResearchSource>[];
    for (final list in results) {
      for (final src in list) {
        final normalizedUrl = src.url.trim().toLowerCase();
        if (normalizedUrl.isEmpty || seenUrls.contains(normalizedUrl)) continue;
        seenUrls.add(normalizedUrl);
        merged.add(src);
        if (merged.length >= maxSources) break;
      }
      if (merged.length >= maxSources) break;
    }

    return ResearchBundle(
      query: query,
      sources: List<ResearchSource>.unmodifiable(merged),
      fetchedAt: DateTime.now(),
    );
  }

  Future<List<ResearchSource>> _queryDuckDuckGo(
    String query, {
    required Duration timeout,
  }) async {
    try {
      final uri = Uri.https('api.duckduckgo.com', '/', <String, String>{
        'q': query,
        'format': 'json',
        'no_html': '1',
        'skip_disambig': '1',
      });
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) return const <ResearchSource>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const <ResearchSource>[];

      final sources = <ResearchSource>[];
      final abstractText = (decoded['AbstractText'] as String?)?.trim() ?? '';
      final abstractUrl = (decoded['AbstractURL'] as String?)?.trim() ?? '';
      final heading = (decoded['Heading'] as String?)?.trim() ?? query;
      if (abstractText.isNotEmpty && abstractUrl.isNotEmpty) {
        sources.add(
          ResearchSource(
            title: heading,
            url: abstractUrl,
            snippet: abstractText,
          ),
        );
      }

      final related = decoded['RelatedTopics'];
      if (related is List<Object?>) {
        for (final item in related) {
          if (item is Map<String, dynamic>) {
            final text = (item['Text'] as String?)?.trim() ?? '';
            final url = (item['FirstURL'] as String?)?.trim() ?? '';
            if (text.isNotEmpty && url.isNotEmpty) {
              final title = text.split(' - ').first.trim();
              sources.add(
                ResearchSource(
                  title: title.isNotEmpty ? title : query,
                  url: url,
                  snippet: text,
                ),
              );
            }
          }
          if (sources.length >= 4) break;
        }
      }
      return sources;
    } catch (_) {
      return const <ResearchSource>[];
    }
  }

  Future<List<ResearchSource>> _queryWikipedia(
    String query, {
    required Duration timeout,
  }) async {
    try {
      final uri = Uri.https('en.wikipedia.org', '/w/api.php', <String, String>{
        'action': 'opensearch',
        'search': query,
        'limit': '3',
        'namespace': '0',
        'format': 'json',
      });
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) return const <ResearchSource>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! List<Object?> || decoded.length < 4) {
        return const <ResearchSource>[];
      }
      final titles = decoded[1] is List<Object?>
          ? (decoded[1] as List<Object?>).whereType<String>().toList()
          : const <String>[];
      final descriptions = decoded[2] is List<Object?>
          ? (decoded[2] as List<Object?>).whereType<String>().toList()
          : const <String>[];
      final urls = decoded[3] is List<Object?>
          ? (decoded[3] as List<Object?>).whereType<String>().toList()
          : const <String>[];

      final sources = <ResearchSource>[];
      for (var i = 0; i < titles.length && i < urls.length; i++) {
        final snippet = i < descriptions.length && descriptions[i].trim().isNotEmpty
            ? descriptions[i].trim()
            : 'Wikipedia article on ${titles[i]}.';
        sources.add(
          ResearchSource(
            title: titles[i],
            url: urls[i],
            snippet: snippet,
            domain: 'en.wikipedia.org',
          ),
        );
      }
      return sources;
    } catch (_) {
      return const <ResearchSource>[];
    }
  }
}
