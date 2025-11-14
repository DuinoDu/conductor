import { Module } from '@nestjs/common';

import { AppController } from './app.controller';
import { DatabaseModule } from './database';
import { MessageService } from './message';
import { ProjectService, TaskService } from './project-task';
import { RepositoryModule } from './repositories';
import { ProjectsController } from './projects/projects.controller';
import { TasksController } from './tasks/tasks.controller';
import { RealtimeModule } from './realtime';

@Module({
  imports: [DatabaseModule, RepositoryModule, RealtimeModule],
  controllers: [AppController, ProjectsController, TasksController],
  providers: [ProjectService, TaskService, MessageService],
})
export class AppModule {}
