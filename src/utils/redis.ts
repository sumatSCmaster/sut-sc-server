import * as redis from 'redis';

function getRedis(): Promise<redis.RedisClient> {
  return new Promise((res, rej) => {
    const client: redis.RedisClient = redis.createClient({ url: process.env.REDIS_URL });
    client.on('ready', () => {
      res(client);
    });
    client.on('error', rej);
  });
}

export default class Redis {
  private static instance: redis.RedisClient;

  private constructor() {}

  public static async getInstance() {
    if (!this.instance) {
      try {
        Redis.instance = await getRedis();
      } catch (e) {}
    }
    return Redis.instance;
  }
}
