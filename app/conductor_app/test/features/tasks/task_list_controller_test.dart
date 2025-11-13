import 'package:conductor_app/src/features/tasks/task_list_controller.dart';
import 'package:conductor_app/src/features/tasks/task_repository.dart';
import 'package:conductor_app/src/models/task.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._tasks);

  final List<Task> _tasks;

  @override
  Future<List<Task>> fetchTasks() async => _tasks;
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
}
