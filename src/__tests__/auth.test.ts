import { post } from '@utils/tests';

describe('ROUTE /auth', () => {
  it('POST /login with invalid credentials', async done => {
    const body = {
      username: 'test',
      password: 'test'
    };
    const response = await post('/auth/login', body);
    expect(response.status).toEqual(401);
    done();
  });

  it('POST /login with valid credentials', async done => {
    const body = {
      username: 'admin2',
      password: 'admin'
    };
    const response = await post('/auth/login', body);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('user');
    done();
  });
});