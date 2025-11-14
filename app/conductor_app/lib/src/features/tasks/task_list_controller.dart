import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers.dart';

final taskListProvider = AutoDisposeAsyncNotifierProvider<TaskListNotifier, List<Task>>(
  TaskListNotifier.new,
);

class TaskListNotifier extends AutoDisposeAsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    return _load();
  }

  Future<List<Task>> reload() async {
    state = const AsyncLoading();
    final tasks = await _load();
    state = AsyncData(tasks);
    return tasks;
  }

  Future<Task> createTask({required String projectId, required String title}) async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.createTask(projectId: projectId, title: title);
    final current = state.value;
    if (current != null) {
      state = AsyncData([task, ...current]);
    } else {
      await reload();
    }
    return task;
  }

  void updateTaskStatus(String taskId, String status) {
    final current = state.value;
    if (current == null || current.isEmpty) {
      return;
    }
    final updated = [
      for (final task in current)
        if (task.id == taskId) task.copyWith(status: status) else task,
    ];
    state = AsyncData(updated);
  }

  Future<List<Task>> _load() async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.fetchTasks();
  }
}
