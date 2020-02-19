import { get, post, put } from "@utils/tests";

describe('ROUTE /institution', () => {
  it('GET / without credentials', async done => {
    const response = await get('/institution');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with credentials', async done => {
    const response = await get('/institution', true);
    expect(response.status).toEqual(200);
    expect(Array.isArray(response.body.institutions)).toBeTruthy();
    done();
  });

  it('POST / without credentials', async done => {
    const response = await post('/institution', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('POST / with invalid body', async done => {
    const response = await post('/institution', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / with valid body', async done => {
    const body = {
      nombre: 'Waku'
    };
    const response = await post('/institution', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('institution');
    done();
  });

  it('PUT /:id without credentials', async done => {
    const response = await put('/institution/0', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /:id with invalid id', async done => {
    const response = await put('/institution/test', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    done();
  });

  it('PUT /:id with invalid body', async done => {
    const response = await put('/institution/1', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with non-existent institution', async done => {
    const body = {
      nombre: 'Waku'
    };
    const response = await put('/institution/0', body, true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PUT /:id with existent institution', async done => {
    const body = {
      nombre: 'Waku'
    };
    const response = await put('/institution/1', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('institution');
    done();
  });

  it('GET /:id without credentials', async done => {
    const response = await get('/institution/0');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET /:id with invalid id', async done => {
    const response = await get('/institution/test', true);
    expect(response.status).toEqual(500);
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('GET /:id with non-existent institution', async done => {
    const response = await get('/institution/0', true);
    expect(response.status).toEqual(404);
    done();
  });

  it('GET /:id with existent institution', async done => {
    const response = await get('/institution/1', true);
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('institution');
    done();
  });
});