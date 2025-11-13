import RedisMock from 'ioredis-mock';

import { AgentTokenService } from '../../src';

describe('AgentTokenService', () => {
  const redis = new (RedisMock as any)();
  const service = new AgentTokenService(redis);

  afterAll(async () => {
    await redis.quit();
  });

  it('issues and validates tokens', async () => {
    const record = await service.issueToken(['project-1', 'project-2']);
    expect(record.token).toHaveLength(48);
    const fetched = await service.validateToken(record.token);
    expect(fetched?.projectIds).toEqual(['project-1', 'project-2']);
  });

  it('returns null for unknown token', async () => {
    const unknown = await service.validateToken('missing');
    expect(unknown).toBeNull();
  });
});
