import { DeepPartial, Repository } from 'typeorm';

import { ProjectEntity } from '../entities';

export interface CreateProjectInput {
  name: string;
  description?: string;
  metadata?: Record<string, unknown>;
}

export class ProjectRepository {
  constructor(private readonly repo: Repository<ProjectEntity>) {}

  static create(repo: Repository<ProjectEntity>): ProjectRepository {
    return new ProjectRepository(repo);
  }

  async createProject(input: CreateProjectInput): Promise<ProjectEntity> {
    const project = this.repo.create(input as DeepPartial<ProjectEntity>);
    return this.repo.save(project);
  }

  async findById(id: string): Promise<ProjectEntity | null> {
    return this.repo.findOne({ where: { id } });
  }

  async listProjects(): Promise<ProjectEntity[]> {
    return this.repo.find({
      order: { createdAt: 'ASC' },
    });
  }
}
