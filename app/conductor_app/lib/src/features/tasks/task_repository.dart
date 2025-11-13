import '../../data/http_client.dart';
import '../../models/task.dart';

abstract class TaskRepository {
  Future<List<Task>> fetchTasks();
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
}
