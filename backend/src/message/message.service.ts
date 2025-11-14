import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { MessageRepository } from '../repositories/message.repository';
import { TaskRepository } from '../repositories/task.repository';
import { MessageEntity, MessageRole } from '../entities';
import { RealtimeHub } from '../realtime';
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

@Injectable()
export class MessageService {
  constructor(
    private readonly messageRepository: MessageRepository,
    private readonly taskRepository: TaskRepository,
    private readonly realtimeHub: RealtimeHub,
  ) {}

  async createMessage(dto: CreateMessageDto): Promise<MessageEntity> {
    try {
      validateMarkdown(dto.content);
    } catch (error) {
      throw new BadRequestException((error as Error).message);
    }
    const task = await this.taskRepository.findById(dto.taskId);
    if (!task) {
      throw new NotFoundException(`Task ${dto.taskId} not found`);
    }
    const message = await this.messageRepository.createMessage({
      task,
      role: dto.role,
      content: dto.content,
      metadata: dto.metadata,
    });
    this.broadcastMessage(message);
    return message;
  }

  listMessages(taskId: string, options: ListMessagesOptions = {}) {
    const limit = options.limit ?? 50;
    const offset = options.offset ?? 0;
    return this.messageRepository.listByTask(taskId, limit, offset);
  }

  private broadcastMessage(message: MessageEntity): void {
    const projectId = message.task.project?.id;
    if (!projectId) {
      return;
    }
    const payload = {
      task_id: message.task.id,
      project_id: projectId,
      message_id: message.id,
      role: message.role,
      content: message.content,
      metadata: message.metadata ?? null,
      created_at: message.createdAt.toISOString(),
    };
    const route = {
      taskId: message.task.id,
      projectId,
      type: this.resolveEventType(message.role),
      data: payload,
    };
    if (message.role === MessageRole.USER) {
      this.realtimeHub.routeToProjectAgents(route);
    } else if (message.role === MessageRole.SDK) {
      this.realtimeHub.routeToProjectApps(route);
    }
  }

  private resolveEventType(role: MessageRole): string {
    if (role === MessageRole.SDK) {
      return 'task_sdk_message';
    }
    return 'task_user_message';
  }
}
