import { get, put } from "@utils/tests";

describe('ROUTE /notification', () => {
  it('GET / without credentials', async done => {
    const response = await get('/notification');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with credentials', async done => {
    const response = await get('/notification', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('notifications');
    expect(Array.isArray(response.body.notifications)).toBeTruthy();
    done();
  });

  it('PUT /markAsRead without credentials', async done => {
    const response = await put('/notification/markAsRead', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /markAsRead with credentials', async done => {
    const response = await put('/notification/markAsRead', {}, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('read');
    done();
  });
});