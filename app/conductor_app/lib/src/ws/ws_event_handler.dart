import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/chat_controller.dart';
import '../features/logs/log_view_page.dart';
import '../features/tasks/task_list_controller.dart';
import '../models/log_entry.dart';
import '../models/message.dart';
import 'message_stream_provider.dart';

class WsEventListener {
  WsEventListener(this._ref);

  final Ref _ref;
  StreamSubscription? _subscription;

  void bind(Stream<dynamic> stream) {
    _subscription?.cancel();
    _subscription = stream.listen(_handleEvent, onError: (err) {});
  }

  void _handleEvent(dynamic payload) {
    final Map<String, dynamic>? data = _normalize(payload);
    if (data == null) return;
    final type = data['type'];
    if (type == 'task_user_message' || type == 'task_sdk_message') {
      _handleChatEvent(data);
    } else if (type == 'task_log_chunk') {
      _handleLogEvent(data);
    } else if (type == 'task_status_update') {
      _handleTaskStatusEvent(data);
    }
  }

  Map<String, dynamic>? _normalize(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return null;
  }

  void _handleChatEvent(Map<String, dynamic> event) {
    final body = event['payload'];
    if (body is! Map<String, dynamic>) return;
    final taskId = body['task_id'] as String?;
    if (taskId == null) return;
    final role = body['role'] as String? ?? 'user';
    final message = Message.fromJson({
      'id': body['id'] ?? DateTime.now().toIso8601String(),
      'task_id': taskId,
      'role': role,
      'content': body['content'] ?? '',
      'created_at': body['created_at'] ?? DateTime.now().toIso8601String(),
    });
    final notifier = _ref.read(chatProvider(taskId).notifier);
    notifier.appendLocal(message);
    if (role != 'user') {
      _ref.read(unreadTaskProvider.notifier).markUnread(taskId);
    }
  }

  void _handleLogEvent(Map<String, dynamic> event) {
    final body = event['payload'];
    if (body is! Map<String, dynamic>) return;
    final taskId = body['task_id'] as String?;
    if (taskId == null) return;
    final entry =
        LogEntry(level: body['level'] ?? 'INFO', message: body['chunk'] ?? '');
    final notifier = _ref.read(logEntriesProvider(taskId).notifier);
    notifier.state = [...notifier.state, entry];
  }

  void _handleTaskStatusEvent(Map<String, dynamic> event) {
    final body = event['payload'];
    if (body is! Map<String, dynamic>) return;
    final taskId = body['task_id'] as String?;
    final status = body['status'] as String?;
    if (taskId == null || status == null) return;
    _ref.read(taskListProvider.notifier).updateTaskStatus(taskId, status);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}

final wsEventListenerProvider = Provider<WsEventListener>((ref) {
  final listener = WsEventListener(ref);
  final stream = ref.watch(wsMessageStreamProvider.stream);
  listener.bind(stream);
  ref.onDispose(listener.dispose);
  return listener;
});
