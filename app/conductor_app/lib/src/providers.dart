import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_config.dart';
import 'data/auth_storage.dart';
import 'data/http_client.dart';
import 'features/tasks/task_repository.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  // Default base URL can be overridden in tests or via top-level ProviderScope overrides.
  return const AppConfig(baseUrl: 'http://localhost:3000');
});

final authStorageProvider = Provider<AuthStorage>((ref) {
  // In production this should be replaced with secure storage implementation.
  return InMemoryAuthStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    authStorage: ref.watch(authStorageProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return HttpTaskRepository(ref.watch(apiClientProvider));
});
