import request, { Test } from 'supertest';
import app from '@root/index';

const token: string = 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOnsiaWQiOiJ2LTI3LjEzOS4xNTMiLCJhZG1pbiI6dHJ1ZSwibGVmdCI6MCwicmlnaHQiOjN9LCJhaXQiOjE1ODA5MDg4OTI0NDh9.mvkdv4phNhnc2FxtGVxgeFm8y3lRSYkptChibx5sHBY'

export const get = (url: string, includeToken: boolean = false): Test => {
  return !includeToken ? 
    request(app).get(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json') :
    request(app).get(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json')
      .set('Authorization', token);
};

export const put = (url: string, body: any, includeToken: boolean = false): Test => {
  return !includeToken ? 
    request(app).put(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json')
      .send(body) :
    request(app).put(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json')
      .set('Authorization', token)
      .send(body);
};

export const post = (url: string, body: any, includeToken: boolean = false): Test => {
  return !includeToken ? 
    request(app).post(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json')
      .send(body) :
    request(app).post(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json')
      .set('Authorization', token)
      .send(body);
};

export const _delete = (url: string, includeToken: boolean = false): Test => {
  return !includeToken ? 
    request(app).delete(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json') :
    request(app).delete(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json')
      .set('Authorization', token);
};

export const patch = (url: string, includeToken: boolean = false): Test => {
  return !includeToken ? 
    request(app).patch(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json') :
    request(app).patch(url)
      .set('Accept', 'application/json')
      .set('Content-Type', 'application/json')
      .set('Authorization', token);
};