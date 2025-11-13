import { DataSource } from 'typeorm';

import { createAppDataSource, isTestEnv } from '../../src/database';

describe('createAppDataSource', () => {
  let dataSource: DataSource;

  afterEach(async () => {
    if (dataSource?.isInitialized) {
      await dataSource.destroy();
    }
  });

  it('creates an in-memory sqlite data source in test env', async () => {
    expect(isTestEnv()).toBe(true);
    dataSource = createAppDataSource();
    await expect(dataSource.initialize()).resolves.not.toThrow();
    const queryRunner = dataSource.createQueryRunner();
    const tables = await queryRunner.getTables(['projects', 'tasks', 'messages']);
    expect(tables).toHaveLength(3);
    await queryRunner.release();
  });
});
