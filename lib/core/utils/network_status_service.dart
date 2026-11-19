import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/app_constants.dart';

/// Provides the active [NetworkStatusService] checking Android connectivity.
final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  return NetworkStatusService();
});

/// Reactive connectivity stream provider for offline-to-online recovery UI (Module 18).
final networkOnlineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(networkStatusServiceProvider);
  return service.watchOnlineStatus();
});

/// Checks real-time internet availability via the native Android
/// `ConnectivityManager` channel before dispatching cloud AI requests.
class NetworkStatusService {
  NetworkStatusService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(AppConstants.automationMethodChannel);

  final MethodChannel _channel;
  DateTime? _lastOnlineCheckAt;
  bool? _lastOnlineResult;

  /// Returns `true` if an internet-capable network is active, or `true` when
  /// running in host environments without Android platform channels.
  Future<bool> isOnline() async {
    final now = DateTime.now();
    if (_lastOnlineResult == true &&
        _lastOnlineCheckAt != null &&
        now.difference(_lastOnlineCheckAt!).inMilliseconds < 2500) {
      return true;
    }
    try {
      final online = await _channel.invokeMethod<bool>('isNetworkConnected');
      final resolved = online ?? true;
      _lastOnlineResult = resolved;
      _lastOnlineCheckAt = now;
      return resolved;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  /// Emits connectivity transitions so offline drafts can surface a one-tap
  /// "Back online — Retry" prompt when internet access returns (Module 18).
  Stream<bool> watchOnlineStatus({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    var last = await isOnline();
    yield last;
    await for (final _ in Stream<void>.periodic(interval)) {
      _lastOnlineCheckAt = null;
      final current = await isOnline();
      if (current != last) {
        last = current;
        yield current;
      }
    }
  }
}
