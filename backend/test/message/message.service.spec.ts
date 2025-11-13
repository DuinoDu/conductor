import { DataSource } from 'typeorm';

import {
  MessageEntity,
  MessageRepository,
  MessageRole,
  MessageService,
  ProjectEntity,
  ProjectRepository,
  TaskEntity,
  TaskRepository,
  TaskService,
  createAppDataSource,
} from '../../src';

describe('MessageService', () => {
  let dataSource: DataSource;
  let messageRepo: MessageRepository;
  let taskService: TaskService;
  let messageService: MessageService;
  let taskId: string;

  beforeAll(async () => {
    dataSource = createAppDataSource();
    await dataSource.initialize();
    const projectRepo = ProjectRepository.create(dataSource.getRepository(ProjectEntity));
    const taskRepo = TaskRepository.create(dataSource.getRepository(TaskEntity));
    messageRepo = MessageRepository.create(dataSource.getRepository(MessageEntity));
    taskService = new TaskService(projectRepo, taskRepo);
    messageService = new MessageService(messageRepo, taskRepo);

    const project = await projectRepo.createProject({ name: 'Message Project' });
    const task = await taskService.createTask({ projectId: project.id, title: 'Chat Task' });
    taskId = task.id;
  });

  afterAll(async () => {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  });

  it('creates messages with markdown validation', async () => {
    const content = 'Hello **world**\n```ts\nconsole.log(1);\n```';
    const message = await messageService.createMessage({
      taskId,
      role: MessageRole.USER,
      content,
    });
    expect(message.content).toEqual(content);
    const list = await messageService.listMessages(taskId);
    expect(list).toHaveLength(1);
  });

  it('rejects dangerous markdown', async () => {
    await expect(
      messageService.createMessage({
        taskId,
        role: MessageRole.USER,
        content: '<script>alert(1)</script>',
      }),
    ).rejects.toThrow('HTML tags are not allowed');
  });

  it('rejects unbalanced code fences', async () => {
    await expect(
      messageService.createMessage({
        taskId,
        role: MessageRole.USER,
        content: '```ts\nconsole.log("hi");',
      }),
    ).rejects.toThrow('code fences must be balanced');
  });
});
