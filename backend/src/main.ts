import 'reflect-metadata';
import * as dotenv from 'dotenv';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import {
  AppDataSource,
  createAppDataSource,
  setActiveDataSource,
} from './database';

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
  setActiveDataSource(dataSource);

  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const port = Number(process.env.PORT || 4000);
  await app.listen(port);
  console.log(`Conductor backend listening on http://localhost:${port}`);
}

bootstrap().catch((err) => {
  console.error('Failed to start backend', err);
  process.exit(1);
});
