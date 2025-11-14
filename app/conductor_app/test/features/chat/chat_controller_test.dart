import 'package:conductor_app/src/features/chat/chat_controller.dart';
import 'package:conductor_app/src/features/chat/chat_repository.dart';
import 'package:conductor_app/src/models/message.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository(this._messages, {this.shouldFail = false});

  final List<Message> _messages;
  final bool shouldFail;
  int sendCount = 0;
  String? lastContent;

  @override
  Future<List<Message>> fetchMessages(String taskId) async => _messages;

  @override
  Future<void> sendMessage(String taskId,
      {required String content, String role = 'sdk'}) async {
    sendCount += 1;
    lastContent = content;
    if (shouldFail) {
      throw Exception('send failed');
    }
  }
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

  test('sendMessage appends local message immediately', () async {
    final repo = FakeChatRepository(const []);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(chatProvider('t1').future);
    await container.read(chatProvider('t1').notifier).sendMessage('hello');

    final messages = container.read(chatProvider('t1')).value!;
    expect(messages.single.content, 'hello');
    expect(repo.sendCount, 1);
  });

  test('sendMessage rolls back optimistic entry on error', () async {
    final repo = FakeChatRepository(const [], shouldFail: true);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(chatProvider('t1').future);
    await expectLater(
      container.read(chatProvider('t1').notifier).sendMessage('oops'),
      throwsException,
    );
    final state = container.read(chatProvider('t1'));
    expect(state.value, isEmpty);
  });
}
