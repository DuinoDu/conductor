import '../../data/http_client.dart';
import '../../models/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> fetchProjects();
  Future<Project> createProject({required String name, String? description});
}

class HttpProjectRepository implements ProjectRepository {
  HttpProjectRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Project>> fetchProjects() async {
    final response = await _client.get<List<dynamic>>('/projects');
    final data = response.data ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Project.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Project> createProject({required String name, String? description}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/projects',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    final body = response.data ?? const {};
    return Project.fromJson(body as Map<String, dynamic>);
  }
}
