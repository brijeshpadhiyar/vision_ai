import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/services/ai_router.dart';
import 'package:vision_ai/features/notifications/domain/entities/notification_digest.dart';
import 'package:vision_ai/features/notifications/domain/services/notification_privacy_filter.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

final notificationDigestServiceProvider = Provider<NotificationDigestService>((
  ref,
) {
  final router = ref.watch(aiRouterProvider);
  return NotificationDigestService(aiRouter: router);
});

/// Summarizes privacy-cleared unread notifications into a spoken multilingual
/// briefing (EN/HI/GU) with 1-tap contextual Smart Reply suggestions.
///
/// Automatically falls back to deterministic on-device grouping if offline or
/// when no cloud AI provider is available.
class NotificationDigestService {
  const NotificationDigestService({this.aiRouter});

  final AIRouter? aiRouter;

  static const Set<String> _messagingPackages = <String>{
    'com.whatsapp',
    'com.whatsapp.w4b',
    'org.telegram.messenger',
    'com.google.android.apps.messaging',
    'com.android.mms',
    'com.instagram.android',
    'com.facebook.orca',
  };

  /// Generates a [NotificationDigest] from raw [notifications].
  ///
  /// Sensitive OTP, UPI, and banking alerts are stripped locally via
  /// [NotificationPrivacyFilter] before any prompt is constructed.
  Future<NotificationDigest> generateDigest({
    required List<DeviceNotificationSummary> notifications,
    required AppSettings settings,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final filtered = NotificationPrivacyFilter.partition(notifications);

    if (filtered.safeForAi.isEmpty) {
      return buildOfflineFallback(
        filtered: filtered,
        language: settings.selectedVoiceLanguage,
        now: timestamp,
      );
    }

    final router = aiRouter;
    if (router != null) {
      try {
        final prompt = buildDigestPrompt(
          items: filtered.safeForAi,
          language: settings.selectedVoiceLanguage,
          protectedCount: filtered.protectedLocal.length,
        );
        final completionRequest = AiCompletionRequest(
          provider: settings.selectedAiProvider,
          modelId: settings.selectedModelId,
          messages: <ChatMessage>[
            ChatMessage(
              id: 'digest_req_${timestamp.millisecondsSinceEpoch}',
              sender: MessageSender.user,
              content: prompt,
              createdAt: timestamp,
            ),
          ],
          responseLanguage: settings.selectedVoiceLanguage,
          temperature: 0.3,
          maxOutputTokens: 900,
          enableDeviceActions: false,
        );
        final response = await router.routeAndGenerate(
          completionRequest: completionRequest,
          settings: settings,
          promptText: prompt,
        );
        final parsed = parseAiDigestJson(
          rawText: response.text,
          safeItems: filtered.safeForAi,
          protectedLocalCount: filtered.protectedLocal.length,
          language: settings.selectedVoiceLanguage,
          now: timestamp,
        );
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Fall back gracefully to offline deterministic digest.
      }
    }

    return buildOfflineFallback(
      filtered: filtered,
      language: settings.selectedVoiceLanguage,
      now: timestamp,
    );
  }

  /// Builds a compact JSON-only prompt containing ONLY privacy-cleared items.
  static String buildDigestPrompt({
    required List<DeviceNotificationSummary> items,
    required VoiceLanguage language,
    required int protectedCount,
  }) {
    final langLabel = switch (language) {
      VoiceLanguage.hindi => 'Hindi (natural conversational Hinglish/Devanagari)',
      VoiceLanguage.gujarati => 'Gujarati (natural conversational Gujarati)',
      VoiceLanguage.english => 'English (concise Indian English)',
      VoiceLanguage.auto => 'English (concise Indian English)',
    };

    final payload = <Map<String, dynamic>>[
      for (var i = 0; i < items.length; i++)
        <String, dynamic>{
          'index': i,
          'app': items[i].appName,
          'sender': items[i].title,
          'message': items[i].text,
          'canReply': items[i].canReply,
        },
    ];

    return '''
You are VISION AI summarizing a user's unread Android notifications in $langLabel.
Return ONLY valid JSON (no markdown fences) with this schema:
{
  "spoken_summary": "2-3 short natural sentences summarizing what matters most. Mention if there are $protectedCount protected private/banking alerts on device without guessing their contents.",
  "items": [
    {
      "index": 0,
      "priority": "urgent" | "people" | "update",
      "summary": "Short 1-line summary",
      "replies": ["Short reply 1", "Short reply 2"]
    }
  ]
}
Only include 2-3 short "replies" when canReply is true; otherwise use [].
Notifications:
${jsonEncode(payload)}
'''.trim();
  }

  /// Parses structured JSON returned by the AI model into a [NotificationDigest].
  static NotificationDigest? parseAiDigestJson({
    required String rawText,
    required List<DeviceNotificationSummary> safeItems,
    required int protectedLocalCount,
    required VoiceLanguage language,
    required DateTime now,
  }) {
    final cleaned = _stripCodeFences(rawText);
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    final dynamic decoded;
    try {
      decoded = jsonDecode(cleaned.substring(start, end + 1));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final spoken = (decoded['spoken_summary'] as String?)?.trim() ?? '';
    final rawList = decoded['items'];
    final mappedByIndex = <int, DigestItemSummary>{};

    if (rawList is List) {
      for (final entry in rawList) {
        if (entry is! Map) continue;
        final idx = (entry['index'] as num?)?.toInt();
        if (idx == null || idx < 0 || idx >= safeItems.length) continue;
        final source = safeItems[idx];
        final priorityStr = (entry['priority'] as String?)?.toLowerCase() ?? '';
        final priority = switch (priorityStr) {
          'urgent' => DigestItemPriority.urgent,
          'people' => DigestItemPriority.people,
          _ => _inferPriority(source),
        };
        final summary = (entry['summary'] as String?)?.trim();
        final repliesRaw = entry['replies'];
        final replies = <SmartReplySuggestion>[];
        if (source.canReply && repliesRaw is List) {
          for (final r in repliesRaw.take(3)) {
            final text = r.toString().trim();
            if (text.isNotEmpty) {
              replies.add(SmartReplySuggestion(label: text, replyText: text));
            }
          }
        }
        mappedByIndex[idx] = DigestItemSummary(
          notification: source,
          priority: priority,
          oneLineSummary: (summary != null && summary.isNotEmpty)
              ? summary
              : _defaultOneLiner(source),
          suggestedReplies: source.canReply && replies.isEmpty
              ? _defaultReplies(language)
              : replies,
        );
      }
    }

    // Ensure no safe notification is dropped even if the model omitted an index.
    final summaries = <DigestItemSummary>[];
    for (var i = 0; i < safeItems.length; i++) {
      summaries.add(
        mappedByIndex[i] ??
            DigestItemSummary(
              notification: safeItems[i],
              priority: _inferPriority(safeItems[i]),
              oneLineSummary: _defaultOneLiner(safeItems[i]),
              suggestedReplies: safeItems[i].canReply
                  ? _defaultReplies(language)
                  : const <SmartReplySuggestion>[],
            ),
      );
    }

    summaries.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return NotificationDigest(
      generatedAt: now,
      spokenSummary: spoken.isNotEmpty
          ? spoken
          : _buildOfflineSpokenSummary(
              safeItems: safeItems,
              protectedLocalCount: protectedLocalCount,
              language: language,
            ),
      items: List<DigestItemSummary>.unmodifiable(summaries),
      protectedLocalCount: protectedLocalCount,
      usedAi: true,
    );
  }

  /// Pure offline deterministic digest fallback (zero network dependency).
  static NotificationDigest buildOfflineFallback({
    required PrivacyFilteredNotifications filtered,
    required VoiceLanguage language,
    required DateTime now,
  }) {
    final items = filtered.safeForAi
        .map(
          (n) => DigestItemSummary(
            notification: n,
            priority: _inferPriority(n),
            oneLineSummary: _defaultOneLiner(n),
            suggestedReplies: n.canReply
                ? _defaultReplies(language)
                : const <SmartReplySuggestion>[],
          ),
        )
        .toList();
    items.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return NotificationDigest(
      generatedAt: now,
      spokenSummary: _buildOfflineSpokenSummary(
        safeItems: filtered.safeForAi,
        protectedLocalCount: filtered.protectedLocal.length,
        language: language,
      ),
      items: List<DigestItemSummary>.unmodifiable(items),
      protectedLocalCount: filtered.protectedLocal.length,
      usedAi: false,
    );
  }

  static DigestItemPriority _inferPriority(DeviceNotificationSummary n) {
    final lower = '${n.title} ${n.text}'.toLowerCase();
    if (RegExp(r'\b(urgent|asap|emergency|missed call|call me|important)\b')
        .hasMatch(lower)) {
      return DigestItemPriority.urgent;
    }
    if (n.canReply || _messagingPackages.contains(n.packageName.toLowerCase())) {
      return DigestItemPriority.people;
    }
    return DigestItemPriority.update;
  }

  static String _defaultOneLiner(DeviceNotificationSummary n) {
    final sender = n.title.trim();
    final body = n.text.trim();
    if (sender.isEmpty) return body;
    if (body.isEmpty) return sender;
    return '$sender: $body';
  }

  static List<SmartReplySuggestion> _defaultReplies(VoiceLanguage language) {
    return switch (language) {
      VoiceLanguage.hindi => const <SmartReplySuggestion>[
        SmartReplySuggestion(label: 'ठीक है 👍', replyText: 'ठीक है 👍'),
        SmartReplySuggestion(
          label: '10 मिनट में कॉल करता हूँ',
          replyText: '10 मिनट में कॉल करता हूँ।',
        ),
        SmartReplySuggestion(label: 'रास्ते में हूँ', replyText: 'रास्ते में हूँ।'),
      ],
      VoiceLanguage.gujarati => const <SmartReplySuggestion>[
        SmartReplySuggestion(label: 'બરાબર 👍', replyText: 'બરાબર 👍'),
        SmartReplySuggestion(
          label: '10 મિનિટમાં કૉલ કરું છું',
          replyText: '10 મિનિટમાં કૉલ કરું છું.',
        ),
        SmartReplySuggestion(label: 'રસ્તામાં છું', replyText: 'રસ્તામાં છું.'),
      ],
      VoiceLanguage.english || VoiceLanguage.auto => const <SmartReplySuggestion>[
        SmartReplySuggestion(label: 'Got it 👍', replyText: 'Got it 👍'),
        SmartReplySuggestion(
          label: 'Call you in 10 mins',
          replyText: 'Will call you in 10 mins.',
        ),
        SmartReplySuggestion(label: 'On my way', replyText: 'On my way!'),
      ],
    };
  }

  static String _buildOfflineSpokenSummary({
    required List<DeviceNotificationSummary> safeItems,
    required int protectedLocalCount,
    required VoiceLanguage language,
  }) {
    if (safeItems.isEmpty && protectedLocalCount == 0) {
      return switch (language) {
        VoiceLanguage.hindi => 'अभी कोई नया नोटिफिकेशन नहीं है। आप पूरी तरह अपडेटेड हैं।',
        VoiceLanguage.gujarati => 'હમણાં કોઈ નવું નોટિફિકેશન નથી. તમે સંપૂર્ણ અપડેટ છો.',
        _ => 'You have no unread notifications right now. You are all caught up.',
      };
    }

    if (safeItems.isEmpty && protectedLocalCount > 0) {
      return switch (language) {
        VoiceLanguage.hindi =>
          'आपके पास $protectedLocalCount निजी बैंकिंग या OTP अलर्ट हैं, जो सुरक्षा के लिए फोन पर ही रखे गए हैं।',
        VoiceLanguage.gujarati =>
          'તમારી પાસે $protectedLocalCount ખાનગી બેંકિંગ અથવા OTP અલર્ટ છે, જે સુરક્ષા માટે ફોનમાં જ રાખવામાં આવ્યા છે.',
        _ =>
          'You have $protectedLocalCount protected banking or OTP alert${protectedLocalCount == 1 ? '' : 's'} kept private on this device.',
      };
    }

    final highlights = safeItems
        .take(3)
        .map((n) => '${n.appName} from ${n.title}: ${n.text}')
        .join('. ');
    final protectedTail = protectedLocalCount > 0
        ? ' Plus $protectedLocalCount private banking or OTP alert${protectedLocalCount == 1 ? '' : 's'} kept local.'
        : '';
    return 'You have ${safeItems.length} unread update${safeItems.length == 1 ? '' : 's'}. $highlights.$protectedTail';
  }

  static String _stripCodeFences(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final firstNewline = trimmed.indexOf('\n');
    if (firstNewline < 0) return trimmed;
    var body = trimmed.substring(firstNewline + 1);
    final closing = body.lastIndexOf('```');
    if (closing >= 0) {
      body = body.substring(0, closing);
    }
    return body.trim();
  }
}
