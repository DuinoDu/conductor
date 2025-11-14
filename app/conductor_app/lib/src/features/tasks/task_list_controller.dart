import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers.dart';

final currentProjectFilterProvider = StateProvider<String?>((_) => null);

final taskListProvider = AutoDisposeAsyncNotifierProvider<TaskListNotifier, List<Task>>(
  TaskListNotifier.new,
);

class TaskListNotifier extends AutoDisposeAsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    final projectId = ref.watch(currentProjectFilterProvider);
    return _load(projectId);
  }

  Future<List<Task>> reload() async {
    final projectId = ref.read(currentProjectFilterProvider);
    state = const AsyncLoading();
    final tasks = await _load(projectId);
    state = AsyncData(tasks);
    return tasks;
  }

  Future<Task> createTask({required String projectId, required String title}) async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.createTask(projectId: projectId, title: title);
    final filter = ref.read(currentProjectFilterProvider);
    final current = state.value;
    if (current != null) {
      if (filter == null || filter == task.projectId) {
        state = AsyncData([task, ...current]);
      }
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

  Future<List<Task>> _load(String? projectId) async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.fetchTasks(projectId: projectId);
  }
}

class UnreadTaskNotifier extends StateNotifier<Set<String>> {
  UnreadTaskNotifier() : super(<String>{});

  void markUnread(String taskId) {
    if (taskId.isEmpty) return;
    if (state.contains(taskId)) {
      return;
    }
    state = {...state, taskId};
  }

  void markRead(String taskId) {
    if (!state.contains(taskId)) {
      return;
    }
    final next = {...state};
    next.remove(taskId);
    state = next;
  }

  void clear() => state = <String>{};
}

final unreadTaskProvider = StateNotifierProvider<UnreadTaskNotifier, Set<String>>(
  (ref) => UnreadTaskNotifier(),
);
