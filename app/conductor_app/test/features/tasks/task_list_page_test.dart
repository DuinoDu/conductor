import 'package:conductor_app/src/features/tasks/task_list_controller.dart';
import 'package:conductor_app/src/features/tasks/task_list_page.dart';
import 'package:conductor_app/src/features/tasks/task_repository.dart';
import 'package:conductor_app/src/models/task.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._tasks);

  final List<Task> _tasks;

  @override
  Future<List<Task>> fetchTasks() async => _tasks;
}

void main() {
  testWidgets('TaskListPage renders tasks', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(
            FakeTaskRepository(const [
              Task(id: '1', projectId: 'p1', title: 'Demo', status: 'CREATED'),
            ]),
          ),
        ],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsOneWidget);
    expect(find.textContaining('Status'), findsOneWidget);
  });
}
