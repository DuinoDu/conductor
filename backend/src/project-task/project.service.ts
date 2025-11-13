import { Injectable, NotFoundException } from '@nestjs/common';

import { ProjectRepository } from '../repositories/project.repository';

export interface CreateProjectDto {
  name: string;
  description?: string;
  metadata?: Record<string, unknown>;
}

@Injectable()
export class ProjectService {
  constructor(private readonly projectRepository: ProjectRepository) {}

  createProject(dto: CreateProjectDto) {
    return this.projectRepository.createProject(dto);
  }

  listProjects() {
    return this.projectRepository.listProjects();
  }

  async getProject(id: string) {
    const project = await this.projectRepository.findById(id);
    if (!project) {
      throw new NotFoundException(`Project ${id} not found`);
    }
    return project;
  }
}
