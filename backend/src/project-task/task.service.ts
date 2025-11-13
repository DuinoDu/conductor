import { ProjectRepository } from '../repositories/project.repository';
import { TaskRepository } from '../repositories/task.repository';
import { TaskStatus } from '../entities';

export interface CreateTaskDto {
  projectId: string;
  title: string;
}

const transitions: Record<TaskStatus, TaskStatus[]> = {
  [TaskStatus.CREATED]: [TaskStatus.RUNNING, TaskStatus.FAILED],
  [TaskStatus.RUNNING]: [TaskStatus.DONE, TaskStatus.FAILED],
  [TaskStatus.DONE]: [],
  [TaskStatus.FAILED]: [],
};

export class TaskService {
  constructor(
    private readonly projectRepository: ProjectRepository,
    private readonly taskRepository: TaskRepository,
  ) {}

  async createTask(dto: CreateTaskDto) {
    const project = await this.projectRepository.findById(dto.projectId);
    if (!project) {
      throw new Error(`Project ${dto.projectId} not found`);
    }
    return this.taskRepository.createTask({
      project,
      title: dto.title,
    });
  }

  listTasks(projectId: string, status?: TaskStatus) {
    return this.taskRepository.listByProject(projectId, status);
  }

  async updateStatus(taskId: string, status: TaskStatus) {
    const task = await this.taskRepository.findById(taskId);
    if (!task) {
      throw new Error(`Task ${taskId} not found`);
    }
    if (task.status === status) {
      return task;
    }
    const allowed = transitions[task.status] ?? [];
    if (!allowed.includes(status)) {
      throw new Error(`Invalid transition from ${task.status} to ${status}`);
    }
    return this.taskRepository.updateStatus(taskId, status);
  }
}
