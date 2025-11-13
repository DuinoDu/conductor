import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
} from 'typeorm';

import { BaseEntity } from './base.entity';
import { MessageEntity } from './message.entity';
import { ProjectEntity } from './project.entity';

export enum TaskStatus {
  CREATED = 'CREATED',
  RUNNING = 'RUNNING',
  DONE = 'DONE',
  FAILED = 'FAILED',
}

@Entity({ name: 'tasks' })
export class TaskEntity extends BaseEntity {
  @Column({ type: 'varchar', length: 255 })
  title!: string;

  @Column({ type: 'varchar', length: 32, default: TaskStatus.CREATED })
  status!: TaskStatus;

  @ManyToOne(() => ProjectEntity, (project) => project.tasks, {
    nullable: false,
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'project_id' })
  project!: ProjectEntity;

  @OneToMany(() => MessageEntity, (message) => message.task, { cascade: true })
  messages?: MessageEntity[];
}
