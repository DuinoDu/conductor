import { MessageService } from '../../src/message/message.service';
import { MessageRole, TaskEntity } from '../../src/entities';
import { MessageRepository } from '../../src/repositories/message.repository';
import { TaskRepository } from '../../src/repositories/task.repository';
import { RealtimeHub } from '../../src/realtime';

const createMessageRepository = () =>
  ({
    createMessage: jest.fn(),
    listByTask: jest.fn(),
  } as unknown as jest.Mocked<MessageRepository>);

const createTaskRepository = () =>
  ({
    findById: jest.fn(),
  } as unknown as jest.Mocked<TaskRepository>);

const createRealtimeHub = () =>
  ({
    routeToProjectAgents: jest.fn(),
    routeToProjectApps: jest.fn(),
  } as unknown as jest.Mocked<RealtimeHub>);

const createTask = (): TaskEntity =>
  ({
    id: 'task-1',
    project: { id: 'project-1' },
  } as TaskEntity);

const createMessage = (task: TaskEntity, role: MessageRole) =>
  ({
    id: 'message-1',
    task,
    role,
    content: role === MessageRole.USER ? 'hello' : 'hi',
    createdAt: new Date('2024-01-01T00:00:00Z'),
    metadata: null,
  } as any);

describe('MessageService', () => {
  it('broadcasts user messages to agents', async () => {
    const messageRepository = createMessageRepository();
    const taskRepository = createTaskRepository();
    const realtimeHub = createRealtimeHub();
    const service = new MessageService(messageRepository, taskRepository, realtimeHub);
    const task = createTask();
    const message = createMessage(task, MessageRole.USER);
    taskRepository.findById.mockResolvedValue(task);
    messageRepository.createMessage.mockResolvedValue(message);

    await service.createMessage({ taskId: task.id, role: MessageRole.USER, content: 'hello' });

    expect(realtimeHub.routeToProjectAgents).toHaveBeenCalledWith(
      expect.objectContaining({
        projectId: 'project-1',
        type: 'task_user_message',
      }),
    );
    expect(realtimeHub.routeToProjectApps).not.toHaveBeenCalled();
  });

  it('broadcasts sdk messages to apps', async () => {
    const messageRepository = createMessageRepository();
    const taskRepository = createTaskRepository();
    const realtimeHub = createRealtimeHub();
    const service = new MessageService(messageRepository, taskRepository, realtimeHub);
    const task = createTask();
    const message = createMessage(task, MessageRole.SDK);
    taskRepository.findById.mockResolvedValue(task);
    messageRepository.createMessage.mockResolvedValue(message);

    await service.createMessage({ taskId: task.id, role: MessageRole.SDK, content: 'reply' });

    expect(realtimeHub.routeToProjectApps).toHaveBeenCalledWith(
      expect.objectContaining({
        projectId: 'project-1',
        type: 'task_sdk_message',
      }),
    );
    expect(realtimeHub.routeToProjectAgents).not.toHaveBeenCalled();
  });
});
