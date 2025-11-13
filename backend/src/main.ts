import 'reflect-metadata';
import * as dotenv from 'dotenv';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import { AppDataSource, createAppDataSource } from './database';

dotenv.config();

function resolveDataSource() {
  const preferSqlite = !process.env.DB_HOST || process.env.DB_DIALECT === 'sqlite';
  if (preferSqlite) {
    return createAppDataSource({
      type: 'sqlite',
      database: process.env.DB_SQLITE_PATH || './conductor.db',
      synchronize: true,
    });
  }
  return AppDataSource;
}

async function bootstrap() {
  const dataSource = resolveDataSource();
  await dataSource.initialize();
  console.log(`Backend data source initialized (${dataSource.options.type})`);

  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const port = Number(process.env.PORT || 3000);
  await app.listen(port);
  console.log(`Conductor backend listening on http://localhost:${port}`);
}

bootstrap().catch((err) => {
  console.error('Failed to start backend', err);
  process.exit(1);
});
