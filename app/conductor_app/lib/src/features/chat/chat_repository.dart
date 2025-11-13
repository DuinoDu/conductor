import '../../data/http_client.dart';
import '../../models/message.dart';

class ChatRepository {
  ChatRepository(this._client);

  final ApiClient _client;

  Future<List<Message>> fetchMessages(String taskId) async {
    final response = await _client.get<List<dynamic>>('/tasks/$taskId/messages');
    final data = response.data ?? const [];
    return data.whereType<Map<String, dynamic>>().map(Message.fromJson).toList(growable: false);
  }

  Future<void> sendMessage(String taskId, {required String content, String role = 'sdk'}) async {
    await _client.post('/tasks/$taskId/messages', data: {
      'content': content,
      'role': role,
    });
  }
}
