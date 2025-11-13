import { FindOptionsWhere, Repository } from 'typeorm';

import { ProjectEntity, TaskEntity, TaskStatus } from '../entities';

export interface CreateTaskInput {
  id?: string;
  project: ProjectEntity;
  title: string;
  status?: TaskStatus;
}

export class TaskRepository {
  constructor(private readonly repo: Repository<TaskEntity>) {}

  static create(repo: Repository<TaskEntity>): TaskRepository {
    return new TaskRepository(repo);
  }

  async createTask(input: CreateTaskInput): Promise<TaskEntity> {
    const task = this.repo.create({
      id: input.id,
      project: input.project,
      title: input.title,
      status: input.status ?? TaskStatus.CREATED,
    });
    return this.repo.save(task);
  }

  async findById(id: string): Promise<TaskEntity | null> {
    return this.repo.findOne({
      where: { id },
      relations: { project: true },
    });
  }

  async listByProject(projectId?: string, status?: TaskStatus): Promise<TaskEntity[]> {
    const filters: FindOptionsWhere<TaskEntity> = {};
    if (projectId) {
      filters.project = { id: projectId } as ProjectEntity;
    }
    if (status) {
      filters.status = status;
    }
    const hasFilters = Boolean(projectId || status);
    return this.repo.find({
      where: hasFilters ? filters : undefined,
      relations: { project: true },
      order: { createdAt: 'DESC' },
    });
  }

  async updateStatus(id: string, status: TaskStatus): Promise<TaskEntity | null> {
    const task = await this.findById(id);
    if (!task) {
      return null;
    }
    task.status = status;
    return this.repo.save(task);
  }

  async findNextPendingTask(projectId: string): Promise<TaskEntity | null> {
    return this.repo.findOne({
      where: { project: { id: projectId }, status: TaskStatus.CREATED },
      relations: { project: true },
      order: { createdAt: 'ASC' },
    });
  }
}
