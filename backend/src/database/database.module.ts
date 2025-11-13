import { Global, Module } from '@nestjs/common';
import { DataSource } from 'typeorm';

import { getActiveDataSource } from './data-source';

export const DATA_SOURCE = Symbol('DATA_SOURCE');

@Global()
@Module({
  providers: [
    {
      provide: DATA_SOURCE,
      useFactory: (): DataSource => getActiveDataSource(),
    },
  ],
  exports: [DATA_SOURCE],
})
export class DatabaseModule {}
