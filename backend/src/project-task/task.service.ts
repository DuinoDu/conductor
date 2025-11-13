import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { ProjectRepository } from '../repositories/project.repository';
import { TaskRepository } from '../repositories/task.repository';
import { TaskStatus } from '../entities';

export interface CreateTaskDto {
  projectId: string;
  title: string;
  taskId?: string;
}

const transitions: Record<TaskStatus, TaskStatus[]> = {
  [TaskStatus.CREATED]: [TaskStatus.RUNNING, TaskStatus.FAILED],
  [TaskStatus.RUNNING]: [TaskStatus.DONE, TaskStatus.FAILED],
  [TaskStatus.DONE]: [],
  [TaskStatus.FAILED]: [],
};

@Injectable()
export class TaskService {
  constructor(
    private readonly projectRepository: ProjectRepository,
    private readonly taskRepository: TaskRepository,
  ) {}

  async createTask(dto: CreateTaskDto) {
    const project = await this.projectRepository.findById(dto.projectId);
    if (!project) {
      throw new NotFoundException(`Project ${dto.projectId} not found`);
    }
    return this.taskRepository.createTask({
      id: dto.taskId,
      project,
      title: dto.title,
    });
  }

  listTasks(projectId?: string, status?: TaskStatus) {
    return this.taskRepository.listByProject(projectId, status);
  }

  async getTask(taskId: string) {
    const task = await this.taskRepository.findById(taskId);
    if (!task) {
      throw new NotFoundException(`Task ${taskId} not found`);
    }
    return task;
  }

  async updateStatus(taskId: string, status: TaskStatus) {
    const task = await this.taskRepository.findById(taskId);
    if (!task) {
      throw new NotFoundException(`Task ${taskId} not found`);
    }
    if (task.status === status) {
      return task;
    }
    const allowed = transitions[task.status] ?? [];
    if (!allowed.includes(status)) {
      throw new BadRequestException(
        `Invalid transition from ${task.status} to ${status}`,
      );
    }
    return this.taskRepository.updateStatus(taskId, status);
  }
}
