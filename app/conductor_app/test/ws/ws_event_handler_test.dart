import 'dart:async';
import 'dart:convert';

import 'package:conductor_app/src/features/chat/chat_controller.dart';
import 'package:conductor_app/src/features/chat/chat_repository.dart';
import 'package:conductor_app/src/features/logs/log_view_page.dart';
import 'package:conductor_app/src/features/tasks/task_list_controller.dart';
import 'package:conductor_app/src/features/tasks/task_repository.dart';
import 'package:conductor_app/src/models/message.dart';
import 'package:conductor_app/src/models/task.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:conductor_app/src/ws/message_stream_provider.dart';
import 'package:conductor_app/src/ws/ws_event_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeChatRepository implements ChatRepository {
  @override
  Future<List<Message>> fetchMessages(String taskId) async => const [];

  @override
  Future<void> sendMessage(String taskId,
      {required String content, String role = 'sdk'}) async {}
}

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(List<Task> tasks) : _tasks = [...tasks];

  final List<Task> _tasks;

  @override
  Future<List<Task>> fetchTasks() async => [..._tasks];

  @override
  Future<Task> createTask({required String projectId, required String title}) {
    throw UnimplementedError();
  }
}

void main() {
  test('WsEventListener routes chat messages', () async {
    final controller = StreamController<dynamic>();
    final container = ProviderContainer(overrides: [
      wsMessageStreamProvider.overrideWith((ref) => controller.stream),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    ]);
    addTearDown(() => container.dispose());

    container.listen(chatProvider('task1'), (_, __) {});
    container.read(wsEventListenerProvider);

    controller.add(jsonEncode({
      'type': 'task_user_message',
      'payload': {
        'task_id': 'task1',
        'content': 'hello',
        'id': 'm1',
        'role': 'user',
      }
    }));

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final messages = container.read(chatProvider('task1'));
    expect(messages.value?.single.content, 'hello');
  });

  test('WsEventListener routes logs', () async {
    final controller = StreamController<dynamic>();
    final container = ProviderContainer(overrides: [
      wsMessageStreamProvider.overrideWith((ref) => controller.stream),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    ]);
    addTearDown(() => container.dispose());

    container.listen(chatProvider('task1'), (_, __) {});
    container.read(wsEventListenerProvider);

    controller.add(jsonEncode({
      'type': 'task_log_chunk',
      'payload': {
        'task_id': 'task1',
        'chunk': 'line',
        'level': 'INFO',
      }
    }));

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final logs = container.read(logEntriesProvider('task1'));
    expect(logs.single.message, 'line');
  });

  test('WsEventListener applies task status updates', () async {
    final controller = StreamController<dynamic>();
    final container = ProviderContainer(overrides: [
      wsMessageStreamProvider.overrideWith((ref) => controller.stream),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      taskRepositoryProvider.overrideWithValue(
        FakeTaskRepository(const [
          Task(id: 'task1', projectId: 'p1', title: 'Demo', status: 'CREATED'),
        ]),
      ),
    ]);
    addTearDown(() => container.dispose());

    container.read(wsEventListenerProvider);
    final notifier = container.read(taskListProvider.notifier);
    await notifier.reload();

    controller.add(jsonEncode({
      'type': 'task_status_update',
      'payload': {'task_id': 'task1', 'status': 'RUNNING'}
    }));

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final tasks = notifier.state.value!;
    expect(tasks.single.status, 'RUNNING');
  });
}
