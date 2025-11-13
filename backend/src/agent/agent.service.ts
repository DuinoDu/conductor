import { randomUUID } from 'crypto';

import { TaskStatus } from '../entities';
import { AgentTokenService } from '../auth/token.service';
import { RedisKeys, RedisLike, createRedisClient } from '../redis';
import { TaskRepository } from '../repositories';

export interface RegisterAgentInput {
  token: string;
  agentId?: string;
  capabilities?: Record<string, unknown>;
}

export interface AgentRecord {
  agentId: string;
  projectIds: string[];
  capabilities: Record<string, unknown>;
  registeredAt: number;
}

export class AgentService {
  constructor(
    private readonly tokenService: AgentTokenService,
    private readonly taskRepository: TaskRepository,
    private readonly redis: RedisLike = createRedisClient(),
  ) {}

  async registerAgent(input: RegisterAgentInput): Promise<AgentRecord> {
    const tokenRecord = await this.tokenService.validateToken(input.token);
    if (!tokenRecord) {
      throw new Error('Invalid agent token');
    }

    const agentId = input.agentId ?? randomUUID();
    const record: AgentRecord = {
      agentId,
      projectIds: tokenRecord.projectIds,
      capabilities: input.capabilities ?? {},
      registeredAt: Date.now(),
    };

    await this.redis.set(
      RedisKeys.agentCapabilities(agentId),
      JSON.stringify(record),
    );
    await this.heartbeat(agentId);
    return record;
  }

  async heartbeat(agentId: string): Promise<void> {
    await this.redis.set(
      RedisKeys.agentHeartbeat(agentId),
      Date.now().toString(),
    );
  }

  async getAgent(agentId: string): Promise<AgentRecord | null> {
    const raw = await this.redis.get(RedisKeys.agentCapabilities(agentId));
    return raw ? (JSON.parse(raw) as AgentRecord) : null;
  }

  async assignNextTask(agentId: string, projectId: string) {
    const agent = await this.getAgent(agentId);
    if (!agent) {
      throw new Error(`Agent ${agentId} not registered`);
    }
    if (!agent.projectIds.includes(projectId)) {
      throw new Error(`Agent ${agentId} not authorized for project ${projectId}`);
    }
    const task = await this.taskRepository.findNextPendingTask(projectId);
    if (!task) {
      return null;
    }
    await this.taskRepository.updateStatus(task.id, TaskStatus.RUNNING);
    return task;
  }
}
