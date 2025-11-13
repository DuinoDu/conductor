import RedisMock from 'ioredis-mock';
import { DataSource } from 'typeorm';

import {
  AgentService,
  AgentTokenService,
  ProjectEntity,
  ProjectRepository,
  RedisKeys,
  TaskEntity,
  TaskRepository,
  TaskService,
  TaskStatus,
  createAppDataSource,
} from '../../src';

class FakeAgentTokenService extends AgentTokenService {
  private readonly records = new Map<string, { projectIds: string[] }>();

  constructor(private readonly redisInstance: any) {
    super(redisInstance);
  }

  addRecord(token: string, projectIds: string[]) {
    this.records.set(token, { projectIds });
  }

  override async validateToken(token: string) {
    const record = this.records.get(token);
    if (!record) {
      return null;
    }
    return {
      token,
      projectIds: record.projectIds,
      issuedAt: Date.now(),
    };
  }
}

describe('AgentService', () => {
  let dataSource: DataSource;
  let projectId: string;
  let taskRepository: TaskRepository;
  let agentService: AgentService;
  let tokenService: FakeAgentTokenService;
let redis: InstanceType<typeof RedisMock>;

  beforeAll(async () => {
    dataSource = createAppDataSource();
    await dataSource.initialize();
    const projectRepo = ProjectRepository.create(dataSource.getRepository(ProjectEntity));
    taskRepository = TaskRepository.create(dataSource.getRepository(TaskEntity));
    const taskService = new TaskService(projectRepo, taskRepository);
    redis = new (RedisMock as any)();
    tokenService = new FakeAgentTokenService(redis);
    agentService = new AgentService(tokenService, taskRepository, redis);

    const project = await projectRepo.createProject({ name: 'Agent Project' });
    projectId = project.id;
    tokenService.addRecord('token-123', [projectId]);
    await taskService.createTask({ projectId, title: 'Pending Task' });
  });

  afterAll(async () => {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
    await redis.quit();
  });

  it('registers agents and stores capabilities', async () => {
    const record = await agentService.registerAgent({
      token: 'token-123',
      agentId: 'agent-1',
      capabilities: { os: 'mac' },
    });
    expect(record.agentId).toEqual('agent-1');
    const redisRecord = await agentService.getAgent('agent-1');
    expect(redisRecord?.capabilities.os).toEqual('mac');
  });

  it('rejects invalid tokens', async () => {
    await expect(
      agentService.registerAgent({ token: 'invalid', agentId: 'bad' }),
    ).rejects.toThrow('Invalid agent token');
  });

  it('assigns tasks to authorized agents', async () => {
    const task = await agentService.assignNextTask('agent-1', projectId);
    expect(task?.status).toEqual(TaskStatus.CREATED);
    const updated = await taskRepository.findById(task!.id);
    expect(updated?.status).toEqual(TaskStatus.RUNNING);
  });

  it('updates heartbeat timestamp', async () => {
    await agentService.heartbeat('agent-1');
    const heartbeat = await redis.get(RedisKeys.agentHeartbeat('agent-1'));
    expect(heartbeat).not.toBeNull();
  });
});
