import 'package:flutter/foundation.dart';

/// Metadata for a native Android TextToSpeech voice returned by `tts.voices`.
@immutable
class TtsVoiceInfo {
  const TtsVoiceInfo({
    required this.name,
    required this.locale,
    this.quality = 300,
    this.isNetworkConnectionRequired = false,
  });

  factory TtsVoiceInfo.fromMap(Map<Object?, Object?> raw) {
    return TtsVoiceInfo(
      name: (raw['name'] as String?) ?? '',
      locale: (raw['locale'] as String?) ?? 'en-IN',
      quality: (raw['quality'] as num?)?.toInt() ?? 300,
      isNetworkConnectionRequired: (raw['networkRequired'] as bool?) ?? false,
    );
  }

  final String name;
  final String locale;
  final int quality;
  final bool isNetworkConnectionRequired;

  String get friendlyLabel {
    final offlineTag = isNetworkConnectionRequired ? 'Online' : 'Offline';
    final shortName = name.split('-').length >= 3
        ? name.split('-').skip(2).join('-')
        : name;
    return '$shortName ($locale • $offlineTag)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsVoiceInfo &&
        other.name == name &&
        other.locale == locale &&
        other.quality == quality &&
        other.isNetworkConnectionRequired == isNetworkConnectionRequired;
  }

  @override
  int get hashCode =>
      Object.hash(name, locale, quality, isNetworkConnectionRequired);
}
