import { ProjectRepository } from '../repositories/project.repository';

export interface CreateProjectDto {
  name: string;
  description?: string;
  metadata?: Record<string, unknown>;
}

export class ProjectService {
  constructor(private readonly projectRepository: ProjectRepository) {}

  createProject(dto: CreateProjectDto) {
    return this.projectRepository.createProject(dto);
  }

  listProjects() {
    return this.projectRepository.listProjects();
  }

  getProject(id: string) {
    return this.projectRepository.findById(id);
  }
}
