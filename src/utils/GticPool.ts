import { Pool as PgPool, PoolConfig } from 'pg';
require('dotenv').config();
const testing = process.env.NODE_ENV === 'test';

export default class Pool {
  private static instance: PgPool;

  private constructor() {}

  public static getInstance(): PgPool {
    if (!Pool.instance) {
      const opt: PoolConfig = {
        connectionString: process.env.GTIC_DATABASE_URL,
        ssl: { rejectUnauthorized: false },
      };
      Pool.instance = new PgPool(opt);
    }
    return Pool.instance;
  }
}
