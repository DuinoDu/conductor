import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_config.dart';
import 'data/auth_storage.dart';
import 'data/http_client.dart';
import 'features/chat/chat_repository.dart';
import 'features/projects/project_repository.dart';
import 'features/tasks/task_repository.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnv();
});

final authStorageProvider = Provider<AuthStorage>((ref) {
  return EnvAuthStorage();
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

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return HttpProjectRepository(ref.watch(apiClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});
