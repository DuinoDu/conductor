import { Body, Controller, Get, Post } from '@nestjs/common';
import { IsNotEmpty, IsObject, IsOptional, IsString } from 'class-validator';

import { ProjectEntity } from '../entities';
import { CreateProjectDto, ProjectService } from '../project-task';

class CreateProjectRequest implements CreateProjectDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

const toProjectResponse = (project: ProjectEntity) => ({
  id: project.id,
  name: project.name,
  description: project.description ?? null,
  metadata: project.metadata ?? null,
  created_at: project.createdAt.toISOString(),
  updated_at: project.updatedAt?.toISOString() ?? null,
});

@Controller('projects')
export class ProjectsController {
  constructor(private readonly projectService: ProjectService) {}

  @Get()
  async listProjects() {
    const projects = await this.projectService.listProjects();
    return projects.map(toProjectResponse);
  }

  @Post()
  async createProject(@Body() body: CreateProjectRequest) {
    const project = await this.projectService.createProject(body);
    return toProjectResponse(project);
  }
}
