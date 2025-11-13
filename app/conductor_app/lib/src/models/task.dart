class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
  });

  final String id;
  final String projectId;
  final String title;
  final String status;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
    );
  }
}
