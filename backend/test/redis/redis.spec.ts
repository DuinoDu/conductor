import RedisMock from 'ioredis-mock';

import { RedisKeys, createRedisClient } from '../../src';

describe('Redis foundation', () => {
  it('generates stable key names', () => {
    expect(RedisKeys.agentHeartbeat('abc')).toEqual('agent:abc:heartbeat');
    expect(RedisKeys.taskLogChannel('t1')).toEqual('task:t1:logs');
    expect(RedisKeys.projectActiveTasks('p1')).toEqual('project:p1:active_tasks');
  });

  it('creates a redis client via dependency injection', async () => {
    const client = createRedisClient({
      url: 'redis://localhost:6379/0',
      redisCtor: RedisMock as unknown as new (
        ...args: unknown[]
      ) => InstanceType<typeof RedisMock>,
    });
    await client.set(RedisKeys.taskStatus('task123'), 'RUNNING');
    const value = await client.get(RedisKeys.taskStatus('task123'));
    expect(value).toEqual('RUNNING');
    await client.quit();
  });
});
