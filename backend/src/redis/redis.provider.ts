import Redis from 'ioredis';

export interface RedisLike {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<string | null>;
  quit(): Promise<string | void>;
}

type RedisConstructor<T extends RedisLike> = new (...args: unknown[]) => T;

export interface RedisClientFactoryOptions<T extends RedisLike = Redis> {
  url?: string;
  redisCtor?: RedisConstructor<T>;
}

export const createRedisClient = <T extends RedisLike = Redis>(
  options: RedisClientFactoryOptions<T> = {},
): T => {
  const ctor: RedisConstructor<T> =
    (options.redisCtor as RedisConstructor<T>) ??
    ((Redis as unknown) as RedisConstructor<T>);
  const targetUrl = options.url ?? process.env.REDIS_URL ?? 'redis://localhost:6379';
  return new ctor(targetUrl);
};
