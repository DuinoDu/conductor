import 'package:conductor_app/src/features/projects/project_list_controller.dart';
import 'package:conductor_app/src/features/projects/project_repository.dart';
import 'package:conductor_app/src/models/project.dart';
import 'package:conductor_app/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository(List<Project> projects) : _projects = [...projects];

  final List<Project> _projects;

  @override
  Future<List<Project>> fetchProjects() async => [..._projects];

  @override
  Future<Project> createProject({required String name, String? description}) async {
    final project = Project(
      id: 'p${_projects.length + 1}',
      name: name,
      description: description,
    );
    _projects.add(project);
    return project;
  }
}

void main() {
  test('projectListProvider loads projects', () async {
    final container = ProviderContainer(overrides: [
      projectRepositoryProvider.overrideWithValue(
        FakeProjectRepository(const [
          Project(id: 'p1', name: 'Demo', description: 'desc'),
        ]),
      ),
    ]);
    addTearDown(container.dispose);

    final projects = await container.read(projectListProvider.future);
    expect(projects.single.name, 'Demo');
  });

  test('createProject adds to state', () async {
    final container = ProviderContainer(overrides: [
      projectRepositoryProvider.overrideWithValue(FakeProjectRepository(const [])),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(projectListProvider.notifier);
    await notifier.reload();
    final created = await notifier.createProject(name: 'New Project');
    final projects = container.read(projectListProvider).value!;
    expect(created.name, 'New Project');
    expect(projects.first.name, 'New Project');
  });
}
