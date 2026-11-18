import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/app_constants.dart';

/// Provides the active [NetworkStatusService] checking Android connectivity.
final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  return NetworkStatusService();
});

/// Checks real-time internet availability via the native Android
/// `ConnectivityManager` channel before dispatching cloud AI requests.
class NetworkStatusService {
  NetworkStatusService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(AppConstants.automationMethodChannel);

  final MethodChannel _channel;

  /// Returns `true` if an internet-capable network is active, or `true` when
  /// running in host environments without Android platform channels.
  Future<bool> isOnline() async {
    try {
      final online = await _channel.invokeMethod<bool>('isNetworkConnected');
      return online ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }
}
