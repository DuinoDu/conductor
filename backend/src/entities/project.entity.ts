import { Column, Entity, OneToMany } from 'typeorm';

import { BaseEntity } from './base.entity';
import { TaskEntity } from './task.entity';

@Entity({ name: 'projects' })
export class ProjectEntity extends BaseEntity {
  @Column({ type: 'varchar', length: 255 })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ type: 'simple-json', nullable: true })
  metadata?: Record<string, unknown>;

  @OneToMany(() => TaskEntity, (task) => task.project, { cascade: true })
  tasks?: TaskEntity[];
}
