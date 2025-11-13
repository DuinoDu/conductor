import { DataSource } from 'typeorm';

import {
  ProjectEntity,
  ProjectRepository,
  ProjectService,
  TaskEntity,
  TaskRepository,
  TaskService,
  TaskStatus,
  createAppDataSource,
} from '../../src';

describe('Project & Task Service', () => {
  let dataSource: DataSource;
  let projectRepo: ProjectRepository;
  let taskRepo: TaskRepository;
  let projectService: ProjectService;
  let taskService: TaskService;
  let projectId: string;

  beforeAll(async () => {
    dataSource = createAppDataSource();
    await dataSource.initialize();
    projectRepo = ProjectRepository.create(dataSource.getRepository(ProjectEntity));
    taskRepo = TaskRepository.create(dataSource.getRepository(TaskEntity));
    projectService = new ProjectService(projectRepo);
    taskService = new TaskService(projectRepo, taskRepo);
  });

  afterAll(async () => {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  });

  it('creates projects and lists them', async () => {
    const project = await projectService.createProject({
      name: 'Project Alpha',
    });
    projectId = project.id;
    const list = await projectService.listProjects();
    expect(list).toHaveLength(1);
    expect(list[0].name).toEqual('Project Alpha');
  });

  it('creates tasks and filters by status', async () => {
    await taskService.createTask({ projectId, title: 'Task 1' });
    await taskService.createTask({ projectId, title: 'Task 2' });

    const allTasks = await taskService.listTasks(projectId);
    expect(allTasks).toHaveLength(2);

    await taskService.updateStatus(allTasks[0].id, TaskStatus.RUNNING);
    await taskService.updateStatus(allTasks[0].id, TaskStatus.DONE);

    const doneTasks = await taskService.listTasks(projectId, TaskStatus.DONE);
    expect(doneTasks).toHaveLength(1);
    expect(doneTasks[0].status).toEqual(TaskStatus.DONE);
  });

  it('enforces state transitions', async () => {
    const [task] = await taskService.listTasks(projectId, TaskStatus.CREATED);
    await expect(taskService.updateStatus(task.id, TaskStatus.DONE)).rejects.toThrow(
      'Invalid transition',
    );
  });
});
