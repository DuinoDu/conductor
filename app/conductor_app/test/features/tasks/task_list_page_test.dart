import 'package:conductor_app/src/features/tasks/task_list_page.dart';
import 'package:conductor_app/src/features/tasks/task_list_controller.dart';
import 'package:conductor_app/src/features/tasks/task_repository.dart';
import 'package:conductor_app/src/features/projects/project_repository.dart';
import 'package:conductor_app/src/models/task.dart';
import 'package:conductor_app/src/models/project.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:conductor_app/src/ws/message_stream_provider.dart';
import 'package:conductor_app/src/ws/ws_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._tasks);

  final List<Task> _tasks;

  @override
  Future<List<Task>> fetchTasks({String? projectId, String? status}) async {
    return _tasks
        .where((task) => projectId == null || task.projectId == projectId)
        .toList(growable: false);
  }

  @override
  Future<Task> createTask(
      {required String projectId, required String title}) async {
    throw UnimplementedError();
  }
}

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository(this._projects);

  final List<Project> _projects;

  @override
  Future<List<Project>> fetchProjects() async => _projects;

  @override
  Future<Project> createProject({required String name, String? description}) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('TaskListPage renders tasks', (tester) async {
    final overrides = [
      taskRepositoryProvider.overrideWithValue(
        FakeTaskRepository(const [
          Task(
            id: '1',
            projectId: 'p1',
            title: 'Demo',
            status: 'CREATED',
            createdAt: DateTime(2024, 1, 1, 12),
          ),
        ]),
      ),
      projectRepositoryProvider.overrideWithValue(
        FakeProjectRepository(const [
          Project(id: 'p1', name: 'Project', description: null),
        ]),
      ),
      wsMessageStreamProvider.overrideWith((ref) => const Stream.empty()),
      wsConnectionStatusProvider.overrideWith(
        (ref) => Stream.value(WebSocketConnectionState.connected),
      ),
      unreadTaskProvider.overrideWith((ref) {
        final notifier = UnreadTaskNotifier();
        notifier.markUnread('1');
        return notifier;
      }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: TaskListPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsOneWidget);
    expect(find.textContaining('Status'), findsOneWidget);
    expect(find.textContaining('Created'), findsOneWidget);
    expect(find.text('Backend: Connected'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsOneWidget);
  });
}
