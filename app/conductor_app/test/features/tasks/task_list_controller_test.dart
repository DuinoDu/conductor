import 'package:conductor_app/src/features/tasks/task_list_controller.dart';
import 'package:conductor_app/src/features/tasks/task_repository.dart';
import 'package:conductor_app/src/models/task.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(List<Task> tasks) : _tasks = [...tasks];

  final List<Task> _tasks;

  @override
  Future<List<Task>> fetchTasks({String? projectId, String? status}) async {
    return _tasks
        .where((task) => projectId == null || task.projectId == projectId)
        .toList(growable: false);
  }

  @override
  Future<Task> createTask({required String projectId, required String title}) async {
    final task = Task(
      id: '${_tasks.length + 1}',
      projectId: projectId,
      title: title,
      status: 'CREATED',
    );
    _tasks.add(task);
    return task;
  }
}

void main() {
  test('taskListProvider loads tasks from repository', () async {
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(
        FakeTaskRepository(const [
          Task(id: '1', projectId: 'p1', title: 'Demo', status: 'CREATED'),
        ]),
      ),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(taskListProvider.future);
    expect(result, hasLength(1));
    expect(result.first.title, 'Demo');
  });

  test('createTask adds the new task to state', () async {
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository(const [])),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(taskListProvider.notifier);
    await notifier.reload();
    final created =
        await notifier.createTask(projectId: 'p1', title: 'From UI');
    final tasks = container.read(taskListProvider).value!;
    expect(created.title, 'From UI');
    expect(tasks.first.title, 'From UI');
  });

  test('updateTaskStatus updates existing entries', () async {
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(
        FakeTaskRepository(const [
          Task(id: '1', projectId: 'p1', title: 'Demo', status: 'CREATED'),
        ]),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(taskListProvider.notifier);
    await notifier.reload();
    notifier.updateTaskStatus('1', 'RUNNING');
    final tasks = container.read(taskListProvider).value!;
    expect(tasks.first.status, 'RUNNING');
  });
  test('changing project filter refreshes data set', () async {
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(
        FakeTaskRepository(const [
          Task(id: '1', projectId: 'p1', title: 'Demo', status: 'CREATED'),
          Task(id: '2', projectId: 'p2', title: 'Other', status: 'CREATED'),
        ]),
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(taskListProvider.future);
    container.read(currentProjectFilterProvider.notifier).state = 'p2';
    final filtered = await container.read(taskListProvider.future);
    expect(filtered.single.id, '2');
  });

  test('UnreadTaskNotifier tracks unread ids', () {
    final notifier = UnreadTaskNotifier();
    notifier.markUnread('task1');
    expect(notifier.state.contains('task1'), isTrue);
    notifier.markRead('task1');
    expect(notifier.state.contains('task1'), isFalse);
  });
}
