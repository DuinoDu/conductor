import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/project.dart';
import '../../providers.dart';

final projectListProvider =
    AutoDisposeAsyncNotifierProvider<ProjectListNotifier, List<Project>>(
  ProjectListNotifier.new,
);

class ProjectListNotifier extends AutoDisposeAsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    return _load();
  }

  Future<List<Project>> reload() async {
    state = const AsyncLoading();
    final projects = await _load();
    state = AsyncData(projects);
    return projects;
  }

  Future<Project> createProject({required String name, String? description}) async {
    final repo = ref.read(projectRepositoryProvider);
    final project = await repo.createProject(name: name, description: description);
    final current = state.value;
    if (current != null) {
      state = AsyncData([project, ...current]);
    } else {
      await reload();
    }
    return project;
  }

  Future<List<Project>> _load() async {
    final repo = ref.read(projectRepositoryProvider);
    return repo.fetchProjects();
  }
}
