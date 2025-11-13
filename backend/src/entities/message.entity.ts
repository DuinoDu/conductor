import { Column, Entity, JoinColumn, ManyToOne } from 'typeorm';

import { BaseEntity } from './base.entity';
import { TaskEntity } from './task.entity';

export enum MessageRole {
  USER = 'user',
  AI = 'ai',
  SDK = 'sdk',
  SYSTEM = 'system',
  LOG = 'log',
}

@Entity({ name: 'messages' })
export class MessageEntity extends BaseEntity {
  @ManyToOne(() => TaskEntity, (task) => task.messages, {
    nullable: false,
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'task_id' })
  task!: TaskEntity;

  @Column({ type: 'varchar', length: 16 })
  role!: MessageRole;

  @Column({ type: 'text' })
  content!: string;

  @Column({ type: 'simple-json', nullable: true })
  metadata?: Record<string, unknown>;
}
