class Message {
  const Message({required this.id, required this.taskId, required this.role, required this.content});

  final String id;
  final String taskId;
  final String role;
  final String content;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
    );
  }
}
