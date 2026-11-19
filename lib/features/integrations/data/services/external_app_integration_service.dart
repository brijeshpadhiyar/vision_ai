import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:vision_ai/core/constants/app_constants.dart';

/// Supported Module 22 external app integration command kinds.
enum ExternalAppCommandType {
  navigateMaps,
  searchYouTube,
  searchSpotify,
  createCalendarEvent,
  composeEmail,
}

/// Parsed external app command ready for execution via Android intents.
@immutable
class ExternalAppCommand {
  const ExternalAppCommand({
    required this.type,
    required this.primaryValue,
    this.secondaryValue = '',
    this.tertiaryValue = '',
  });

  final ExternalAppCommandType type;
  final String primaryValue;
  final String secondaryValue;
  final String tertiaryValue;
}

/// Module 22: External App Integrations parser & native intent dispatcher.
///
/// Supports Google Maps navigation, YouTube search, Spotify search,
/// Android Calendar event creation, and Email composition.
class ExternalAppIntegrationService {
  ExternalAppIntegrationService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(AppConstants.automationMethodChannel);

  final MethodChannel _channel;

  static final RegExp _youtubeRegex = RegExp(
    r'^(?:(?:play|search|watch|find|open)\s+)?(.+?)\s+(?:on|in)\s+youtube$|^search\s+youtube\s+(?:for\s+)?(.+)$',
    caseSensitive: false,
  );

  static final RegExp _spotifyRegex = RegExp(
    r'^(?:(?:play|search|listen\s+to|find)\s+)?(.+?)\s+(?:on|in)\s+spotify$|^search\s+spotify\s+(?:for\s+)?(.+)$',
    caseSensitive: false,
  );

  static final RegExp _mapsRegex = RegExp(
    r'^(?:navigate\s+to|directions\s+to|route\s+to|open\s+(?:google\s+)?maps\s+(?:for|to))\s+(.+)$',
    caseSensitive: false,
  );

  static final RegExp _calendarRegex = RegExp(
    r'^(?:add\s+(?:a\s+)?calendar\s+event|create\s+(?:a\s+)?calendar\s+event|schedule\s+(?:a\s+)?(?:meeting|event))\s+(?:for\s+|called\s+)?(.+)$',
    caseSensitive: false,
  );

  static final RegExp _emailRegex = RegExp(
    r'^(?:compose|write|send)\s+(?:an?\s+)?(?:email|mail)\s+(?:to\s+)?([^\s]+@[^\s]+)(?:\s+(?:subject|about)\s+(.+))?$',
    caseSensitive: false,
  );

  /// Parses natural-language [input] into an [ExternalAppCommand] if matched.
  static ExternalAppCommand? parseCommand(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final ytMatch = _youtubeRegex.firstMatch(trimmed);
    if (ytMatch != null) {
      final query = (ytMatch.group(1) ?? ytMatch.group(2) ?? '').trim();
      if (query.isNotEmpty) {
        return ExternalAppCommand(
          type: ExternalAppCommandType.searchYouTube,
          primaryValue: query,
        );
      }
    }

    final spotifyMatch = _spotifyRegex.firstMatch(trimmed);
    if (spotifyMatch != null) {
      final query = (spotifyMatch.group(1) ?? spotifyMatch.group(2) ?? '')
          .trim();
      if (query.isNotEmpty) {
        return ExternalAppCommand(
          type: ExternalAppCommandType.searchSpotify,
          primaryValue: query,
        );
      }
    }

    final mapsMatch = _mapsRegex.firstMatch(trimmed);
    if (mapsMatch != null) {
      final destination = (mapsMatch.group(1) ?? '').trim();
      if (destination.isNotEmpty) {
        return ExternalAppCommand(
          type: ExternalAppCommandType.navigateMaps,
          primaryValue: destination,
        );
      }
    }

    final calendarMatch = _calendarRegex.firstMatch(trimmed);
    if (calendarMatch != null) {
      final title = (calendarMatch.group(1) ?? '').trim();
      if (title.isNotEmpty) {
        return ExternalAppCommand(
          type: ExternalAppCommandType.createCalendarEvent,
          primaryValue: title,
        );
      }
    }

    final emailMatch = _emailRegex.firstMatch(trimmed);
    if (emailMatch != null) {
      final recipient = (emailMatch.group(1) ?? '').trim();
      final subject = (emailMatch.group(2) ?? '').trim();
      if (recipient.isNotEmpty) {
        return ExternalAppCommand(
          type: ExternalAppCommandType.composeEmail,
          primaryValue: recipient,
          secondaryValue: subject,
        );
      }
    }

    return null;
  }

  /// Dispatches [command] to Android via `VisionAutomationChannel.kt` and
  /// returns a human-readable confirmation or error summary.
  Future<String> execute(ExternalAppCommand command) async {
    try {
      switch (command.type) {
        case ExternalAppCommandType.navigateMaps:
          await _channel.invokeMethod<Object?>(
            'navigateTo',
            <String, Object>{'destination': command.primaryValue},
          );
          return 'Opened Google Maps navigation to ${command.primaryValue}.';

        case ExternalAppCommandType.searchYouTube:
          final encoded = Uri.encodeQueryComponent(command.primaryValue);
          final url = 'https://www.youtube.com/results?search_query=$encoded';
          await _channel.invokeMethod<Object?>(
            'openExternalUri',
            <String, Object>{'uri': url, 'fallbackUrl': url},
          );
          return 'Opened YouTube search for "${command.primaryValue}".';

        case ExternalAppCommandType.searchSpotify:
          final encoded = Uri.encodeComponent(command.primaryValue);
          await _channel.invokeMethod<Object?>(
            'openExternalUri',
            <String, Object>{
              'uri': 'spotify:search:$encoded',
              'fallbackUrl': 'https://open.spotify.com/search/$encoded',
            },
          );
          return 'Opened Spotify search for "${command.primaryValue}".';

        case ExternalAppCommandType.createCalendarEvent:
          await _channel.invokeMethod<Object?>(
            'createCalendarEvent',
            <String, Object>{
              'title': command.primaryValue,
              'description': command.secondaryValue,
            },
          );
          return 'Opened Calendar to create event "${command.primaryValue}".';

        case ExternalAppCommandType.composeEmail:
          await _channel.invokeMethod<Object?>(
            'composeEmail',
            <String, Object>{
              'to': command.primaryValue,
              'subject': command.secondaryValue,
              'body': command.tertiaryValue,
            },
          );
          return command.secondaryValue.isNotEmpty
              ? 'Opened email composer for ${command.primaryValue} (subject: "${command.secondaryValue}").'
              : 'Opened email composer for ${command.primaryValue}.';
      }
    } on MissingPluginException {
      return 'External app launch (${command.type.name}) is available on Android devices.';
    } on PlatformException catch (e) {
      return e.message ?? 'Unable to launch external app integration.';
    }
  }
}
