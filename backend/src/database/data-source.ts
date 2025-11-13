import 'reflect-metadata';
import { DataSource, DataSourceOptions } from 'typeorm';
import * as dotenv from 'dotenv';

import { MessageEntity, ProjectEntity, TaskEntity } from '../entities';

dotenv.config();

const entities = [ProjectEntity, TaskEntity, MessageEntity];

const postgresOptions: DataSourceOptions = {
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  username: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'conductor',
  synchronize: false,
  logging: false,
  entities,
};

const sqliteOptions: DataSourceOptions = {
  type: 'sqlite',
  database: ':memory:',
  synchronize: true,
  logging: false,
  entities,
};

export const isTestEnv = () => process.env.NODE_ENV === 'test';

let activeDataSource: DataSource | null = null;

export const createAppDataSource = (
  overrides?: Partial<DataSourceOptions>,
): DataSource => {
  const baseOptions = isTestEnv() ? sqliteOptions : postgresOptions;
  return new DataSource({
    ...baseOptions,
    ...overrides,
    entities: overrides?.entities ?? entities,
  } as DataSourceOptions);
};

export const AppDataSource = createAppDataSource();

export const setActiveDataSource = (dataSource: DataSource): void => {
  activeDataSource = dataSource;
};

export const getActiveDataSource = (): DataSource => {
  if (!activeDataSource || !activeDataSource.isInitialized) {
    throw new Error('Data source has not been initialized');
  }
  return activeDataSource;
};
