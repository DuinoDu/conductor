import 'package:conductor_app/src/features/tasks/task_list_page.dart';
import 'package:conductor_app/src/features/tasks/task_repository.dart';
import 'package:conductor_app/src/models/task.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:conductor_app/src/ws/message_stream_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTaskRepository implements TaskRepository {
  @override
  Future<List<Task>> fetchTasks() async => const [];
}

void main() {
  testWidgets('Task list screen renders title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          wsMessageStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );
    expect(find.text('Tasks'), findsOneWidget);
  });
}
