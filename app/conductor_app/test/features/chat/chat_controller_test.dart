import 'package:conductor_app/src/features/chat/chat_controller.dart';
import 'package:conductor_app/src/features/chat/chat_repository.dart';
import 'package:conductor_app/src/models/message.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository(this._messages);

  final List<Message> _messages;

  @override
  Future<List<Message>> fetchMessages(String taskId) async => _messages;

  @override
  Future<void> sendMessage(String taskId,
      {required String content, String role = 'sdk'}) async {}
}

void main() {
  test('chatProvider loads messages', () async {
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(
        FakeChatRepository(const [
          Message(id: 'm1', taskId: 't1', role: 'user', content: 'hello'),
        ]),
      ),
    ]);
    addTearDown(container.dispose);

    final data = await container.read(chatProvider('t1').future);
    expect(data, hasLength(1));
  });
}
