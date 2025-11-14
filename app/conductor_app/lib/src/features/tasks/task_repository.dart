import '../../data/http_client.dart';
import '../../models/task.dart';

abstract class TaskRepository {
  Future<List<Task>> fetchTasks();
  Future<Task> createTask({required String projectId, required String title});
}

class HttpTaskRepository implements TaskRepository {
  HttpTaskRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Task>> fetchTasks() async {
    final response = await _client.get<List<dynamic>>('/tasks');
    final data = response.data ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Task> createTask({required String projectId, required String title}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/tasks',
      data: {
        'projectId': projectId,
        'title': title,
      },
    );
    final body = response.data ?? const {};
    return Task.fromJson(body as Map<String, dynamic>);
  }
}
