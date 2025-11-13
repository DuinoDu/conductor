import { Repository } from 'typeorm';

import { MessageEntity, MessageRole, TaskEntity } from '../entities';

export interface CreateMessageInput {
  task: TaskEntity;
  role: MessageRole;
  content: string;
  metadata?: Record<string, unknown>;
}

export class MessageRepository {
  constructor(private readonly repo: Repository<MessageEntity>) {}

  static create(repo: Repository<MessageEntity>): MessageRepository {
    return new MessageRepository(repo);
  }

  async createMessage(input: CreateMessageInput): Promise<MessageEntity> {
    const message = this.repo.create({
      task: input.task,
      role: input.role,
      content: input.content,
      metadata: input.metadata,
    });
    return this.repo.save(message);
  }

  async listByTask(taskId: string, limit = 50, offset = 0): Promise<MessageEntity[]> {
    return this.repo.find({
      where: { task: { id: taskId } },
      relations: { task: true },
      order: { createdAt: 'ASC', id: 'ASC' },
      take: limit,
      skip: offset,
    });
  }
}
