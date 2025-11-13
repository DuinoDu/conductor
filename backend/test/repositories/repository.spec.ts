import { DataSource } from 'typeorm';

import {
  MessageEntity,
  MessageRepository,
  MessageRole,
  ProjectEntity,
  ProjectRepository,
  TaskEntity,
  TaskRepository,
  TaskStatus,
  createAppDataSource,
} from '../../src';

describe('Repository layer', () => {
  let dataSource: DataSource;
  let projectRepo: ProjectRepository;
  let taskRepo: TaskRepository;
  let messageRepo: MessageRepository;
  let project: ProjectEntity;
  let task: TaskEntity;

  beforeAll(async () => {
    dataSource = createAppDataSource();
    await dataSource.initialize();
    projectRepo = ProjectRepository.create(dataSource.getRepository(ProjectEntity));
    taskRepo = TaskRepository.create(dataSource.getRepository(TaskEntity));
    messageRepo = MessageRepository.create(dataSource.getRepository(MessageEntity));
  });

  afterAll(async () => {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  });

  it('creates and fetches a project', async () => {
    project = await projectRepo.createProject({
      name: 'Test Project',
      description: 'Demo',
    });
    const fetched = await projectRepo.findById(project.id);
    expect(fetched?.name).toEqual('Test Project');
    const all = await projectRepo.listProjects();
    expect(all).toHaveLength(1);
  });

  it('creates tasks and updates status', async () => {
    task = await taskRepo.createTask({
      project,
      title: 'Initial task',
    });
    expect(task.status).toEqual(TaskStatus.CREATED);
    const updated = await taskRepo.updateStatus(task.id, TaskStatus.RUNNING);
    expect(updated?.status).toEqual(TaskStatus.RUNNING);
    const tasks = await taskRepo.listByProject(project.id);
    expect(tasks).toHaveLength(1);
  });

  it('stores messages per task', async () => {
    await messageRepo.createMessage({
      task,
      role: MessageRole.USER,
      content: 'Hello',
    });
    await messageRepo.createMessage({
      task,
      role: MessageRole.AI,
      content: 'Hi!',
    });

    const messages = await messageRepo.listByTask(task.id);
    expect(messages).toHaveLength(2);
    const roles = new Set(messages.map((m) => m.role));
    expect(roles).toEqual(new Set([MessageRole.USER, MessageRole.AI]));
  });
});
