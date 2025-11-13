import { MessageRepository } from '../repositories/message.repository';
import { TaskRepository } from '../repositories/task.repository';
import { MessageEntity, MessageRole } from '../entities';
import { validateMarkdown } from './markdown.validator';

export interface CreateMessageDto {
  taskId: string;
  role: MessageRole;
  content: string;
  metadata?: Record<string, unknown>;
}

export interface ListMessagesOptions {
  limit?: number;
  offset?: number;
}

export class MessageService {
  constructor(
    private readonly messageRepository: MessageRepository,
    private readonly taskRepository: TaskRepository,
  ) {}

  async createMessage(dto: CreateMessageDto): Promise<MessageEntity> {
    validateMarkdown(dto.content);
    const task = await this.taskRepository.findById(dto.taskId);
    if (!task) {
      throw new Error(`Task ${dto.taskId} not found`);
    }
    return this.messageRepository.createMessage({
      task,
      role: dto.role,
      content: dto.content,
      metadata: dto.metadata,
    });
  }

  listMessages(taskId: string, options: ListMessagesOptions = {}) {
    const limit = options.limit ?? 50;
    const offset = options.offset ?? 0;
    return this.messageRepository.listByTask(taskId, limit, offset);
  }
}
