class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? projectId;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Task copyWith({String? status, DateTime? updatedAt}) {
    return Task(
      id: id,
      projectId: projectId,
      title: title,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final updatedAtRaw = json['updated_at'];
    return Task(
      id: json['id'] as String,
      projectId: json['project_id'] as String?,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      createdAt: _parseDateTime(createdAtRaw) ?? DateTime.now(),
      updatedAt: _parseDateTime(updatedAtRaw),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    final asString = value.toString();
    if (asString.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(asString).toLocal();
    } catch (_) {
      return null;
    }
  }
}
