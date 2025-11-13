import { Global, Module } from '@nestjs/common';
import { DataSource } from 'typeorm';

import { DATA_SOURCE } from '../database';
import { MessageEntity, ProjectEntity, TaskEntity } from '../entities';
import { MessageRepository } from './message.repository';
import { ProjectRepository } from './project.repository';
import { TaskRepository } from './task.repository';

@Global()
@Module({
  providers: [
    {
      provide: ProjectRepository,
      useFactory: (dataSource: DataSource) =>
        ProjectRepository.create(dataSource.getRepository(ProjectEntity)),
      inject: [DATA_SOURCE],
    },
    {
      provide: TaskRepository,
      useFactory: (dataSource: DataSource) =>
        TaskRepository.create(dataSource.getRepository(TaskEntity)),
      inject: [DATA_SOURCE],
    },
    {
      provide: MessageRepository,
      useFactory: (dataSource: DataSource) =>
        MessageRepository.create(dataSource.getRepository(MessageEntity)),
      inject: [DATA_SOURCE],
    },
  ],
  exports: [ProjectRepository, TaskRepository, MessageRepository],
})
export class RepositoryModule {}
