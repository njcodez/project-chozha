// lib/providers/api_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'settings_provider.dart';

/// Rebuilds ApiService whenever the backend URL changes.
final apiServiceProvider = Provider<AsyncValue<ApiService>>((ref) {
  final urlAsync = ref.watch(backendUrlProvider);
  return urlAsync.whenData((url) => ApiService(url));
});

/// Convenience: unwraps to ApiService or throws.
/// Use inside AsyncNotifiers / FutureProviders where you already handle loading.
ApiService requireApi(Ref ref) {
  return ref.read(apiServiceProvider).requireValue;
}
