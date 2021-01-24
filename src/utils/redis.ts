import { promisify } from 'util';

import * as redis from 'redis';
import { mainLogger } from './logger';

const dev = process.env.NODE_ENV !== 'production';

function getRedis() {
  const clientConf = dev ? { url: process.env.REDIS_URL } : { url: process.env.REDIS_URL, tls: { rejectUnauthorized: false } };
  const client: redis.RedisClient = redis.createClient(clientConf);
  client.on('ready', () => {
    mainLogger.info(`Redis client ready`);
  });
  client.on('error', (e) => {
    mainLogger.error(`Redis client error ${e.message}`);
  });
  return client;
}

class RedisClient {
  constructor(private readonly redisClient: redis.RedisClient) {}

  getPromise = promisify(this.redisClient.get).bind(this.redisClient);
  setPromise = promisify(this.redisClient.set).bind(this.redisClient);
  expirePromise = promisify(this.redisClient.expire).bind(this.redisClient);

  async getAsync(key: string) {
    try {
      return await this.getPromise(key);
    } catch (e) {
      mainLogger.error(`getAsync ERROR - ${e.message}`);
      throw e;
    }
  }

  async setAsync(key: string, value: string) {
    try {
      return await this.setPromise(key, value);
    } catch (e) {
      mainLogger.error(`setAsync ERROR - ${e.message}`);
      throw e;
    }
  }

  async expireAsync(key: string, time: number) {
    try {
      return await this.expirePromise(key, time);
    } catch (e) {
      mainLogger.error(`setAsync ERROR - ${e.message}`);
      throw e;
    }
  }
}

export default class Redis {
  private static instance: RedisClient;

  private constructor() {}

  public static getInstance() {
    if (!this.instance) {
      try {
        Redis.instance = new RedisClient(getRedis());
      } catch (e) {
        mainLogger.error(`${e.message}`);
      }
    }
    return Redis.instance;
  }
}
