import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import {
  IsEnum,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

import {
  MessageEntity,
  MessageRole,
  TaskEntity,
  TaskStatus,
} from '../entities';
import { MessageService } from '../message';
import { CreateTaskDto, TaskService } from '../project-task';

class CreateTaskRequest implements CreateTaskDto {
  @IsUUID()
  projectId!: string;

  @IsString()
  @IsNotEmpty()
  title!: string;
}

class CreateMessageRequest {
  @IsString()
  @IsNotEmpty()
  content!: string;

  @IsOptional()
  @IsEnum(MessageRole)
  role?: MessageRole;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

const toTaskResponse = (task: TaskEntity) => ({
  id: task.id,
  project_id: task.project?.id ?? null,
  title: task.title,
  status: task.status,
  created_at: task.createdAt.toISOString(),
  updated_at: task.updatedAt?.toISOString() ?? null,
});

const toMessageResponse = (message: MessageEntity) => ({
  id: message.id,
  task_id: message.task.id,
  role: message.role,
  content: message.content,
  created_at: message.createdAt.toISOString(),
});

const parseTaskStatus = (value?: string): TaskStatus | undefined => {
  if (!value) {
    return undefined;
  }
  if ((Object.values(TaskStatus) as string[]).includes(value)) {
    return value as TaskStatus;
  }
  return undefined;
};

@Controller('tasks')
export class TasksController {
  constructor(
    private readonly taskService: TaskService,
    private readonly messageService: MessageService,
  ) {}

  @Get()
  async listTasks(
    @Query('project_id') projectId?: string,
    @Query('status') status?: string,
  ) {
    const taskStatus = parseTaskStatus(status);
    if (status && !taskStatus) {
      throw new BadRequestException(`Invalid status value ${status}`);
    }
    const tasks = await this.taskService.listTasks(projectId, taskStatus);
    return tasks.map(toTaskResponse);
  }

  @Post()
  async createTask(@Body() body: CreateTaskRequest) {
    const task = await this.taskService.createTask(body);
    return toTaskResponse(task);
  }

  @Get(':taskId')
  async getTask(@Param('taskId') taskId: string) {
    const task = await this.taskService.getTask(taskId);
    return toTaskResponse(task);
  }

  @Get(':taskId/messages')
  async listMessages(@Param('taskId') taskId: string) {
    const messages = await this.messageService.listMessages(taskId);
    return messages.map(toMessageResponse);
  }

  @Post(':taskId/messages')
  async createMessage(
    @Param('taskId') taskId: string,
    @Body() body: CreateMessageRequest,
  ) {
    const message = await this.messageService.createMessage({
      taskId,
      content: body.content,
      role: body.role ?? MessageRole.SDK,
      metadata: body.metadata,
    });
    return toMessageResponse(message);
  }
}
