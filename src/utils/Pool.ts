import { Pool as PgPool, PoolConfig } from 'pg';
require('dotenv').config();
const testing = process.env.NODE_ENV === 'test';

export default class Pool {
  private static instance: PgPool;

  private constructor() {}

  public static getInstance(): PgPool {
    if(!Pool.instance) {
      const opt: PoolConfig = {
        database: !testing ? process.env.DB_NAME : process.env.DB_TESTING_NAME,
        host: !testing ? process.env.DB_HOST : process.env.DB_TESTING_HOST,
        user: !testing ? process.env.DB_USER : process.env.DB_TESTING_USER,
        password: !testing ? process.env.DB_PASSWORD : process.env.DB_TESTING_PASSWORD,
        min: 30,
        port: !testing ? (process.env.DB_PORT ? parseInt(process.env.DB_PORT) : 5433) 
          : (process.env.DB_TESTING_PORT ? parseInt(process.env.DB_TESTING_PORT) : 5433)
      }
      Pool.instance = new PgPool(opt);
    }
    return Pool.instance;
  }
} 