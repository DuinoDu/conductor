import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/message.dart';
import '../../providers.dart';
import 'chat_repository.dart';

final chatProvider = AutoDisposeAsyncNotifierProviderFamily<ChatController,
    List<Message>, String>(
  ChatController.new,
);

class ChatController
    extends AutoDisposeFamilyAsyncNotifier<List<Message>, String> {
  late final ChatRepository _repository;
  late String _taskId;

  @override
  @override
  Future<List<Message>> build(String taskId) async {
    _repository = ref.read(chatRepositoryProvider);
    _taskId = taskId;
    return _repository.fetchMessages(taskId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final messages = await _repository.fetchMessages(_taskId);
    state = AsyncData(messages);
  }

  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final optimisticMessage = Message(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      taskId: _taskId,
      role: 'sdk',
      content: trimmed,
      createdAt: DateTime.now(),
    );
    appendLocal(optimisticMessage);
    try {
      await _repository.sendMessage(_taskId, content: trimmed);
    } catch (error) {
      final current = state.value ?? [];
      state = AsyncData(
        current.where((message) => message.id != optimisticMessage.id).toList(),
      );
      rethrow;
    }
  }

  void appendLocal(Message message) {
    final current = state.value ?? const [];
    state = AsyncData([...current, message]);
  }
}
