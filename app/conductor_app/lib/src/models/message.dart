class Message {
  const Message({
    required this.id,
    required this.taskId,
    required this.role,
    required this.content,
    this.createdAt,
  });

  final String id;
  final String taskId;
  final String role;
  final String content;
  final DateTime? createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['created_at'];
    DateTime? timestamp;
    if (createdAtValue is String) {
      timestamp = DateTime.tryParse(createdAtValue);
    }
    return Message(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      createdAt: timestamp,
    );
  }
}
