import { get } from '@utils/tests';

describe('ROUTE /', () => {
  it('GET /', async done => {
    const response = await get('/');
    expect(response.status).toEqual(200);
    done();
  })
})