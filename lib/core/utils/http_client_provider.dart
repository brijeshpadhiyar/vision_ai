import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Provides a shared [http.Client] instance for REST API calls.
///
/// Can be overridden in tests to inject a mock [http.Client].
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
