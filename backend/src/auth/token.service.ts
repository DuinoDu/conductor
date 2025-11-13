import { randomBytes } from 'crypto';

import { RedisKeys, RedisLike, createRedisClient } from '../redis';

export interface TokenRecord {
  token: string;
  projectIds: string[];
  issuedAt: number;
}

export class AgentTokenService {
  constructor(private readonly redis: RedisLike = createRedisClient()) {}

  async issueToken(projectIds: string[]): Promise<TokenRecord> {
    const token = randomBytes(24).toString('hex');
    const record: TokenRecord = {
      token,
      projectIds,
      issuedAt: Date.now(),
    };
    await this.redis.set(this.tokenKey(token), JSON.stringify(record));
    return record;
  }

  async validateToken(token: string): Promise<TokenRecord | null> {
    const raw = await this.redis.get(this.tokenKey(token));
    if (!raw) {
      return null;
    }
    return JSON.parse(raw);
  }

  private tokenKey(token: string): string {
    return RedisKeys.agentCapabilities(token);
  }
}
