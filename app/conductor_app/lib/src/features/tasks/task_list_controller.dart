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

  Future<List<Task>> _load() async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.fetchTasks();
  }
}
