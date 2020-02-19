import { get, post, put, _delete } from "@utils/tests";
let createdOffice = 0;

describe('ROUTE /office (/institution/:id/office)', () => {
  it('GET / without credentials', async done => {
    const response = await get('/institution/1/office');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with invalid institution id', async done => {
    const response = await get('/institution/test/office', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('GET / with valid institution id', async done => {
    const response = await get('/institution/1/office', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('offices');
    done();
  });

  it('POST / without credentials', async done => {
    const response = await post('/institution/1/office', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('POST / with invalid institution id', async done => {
    const response = await post('/institution/test/office', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / with invalid body', async done => {
    const response = await post('/institution/1/office', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / with valid body', async done => {
    const body = {
      nombre: 'Waku'
    };
    const response = await post('/institution/1/office', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('office');
    createdOffice = response.body.office.id;
    done();
  });

  it('PUT /:id without credentials', async done => {
    const response = await put('/institution/1/office/1', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /:id with invalid institution id', async done => {
    const response = await put('/institution/test/office/1', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with invalid office id', async done => {
    const response = await put('/institution/1/office/test', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with non-existent institution', async done => {
    const body = {
      nombre: 'Waku',
      institucion: 1
    };
    const response = await put('/institution/0/office/1', body, true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PUT /:id with non-existent office', async done => {
    const body = {
      nombre: 'Waku',
      institucion: 1
    };
    const response = await put('/institution/1/office/0', body, true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PUT /:id with invalid body', async done => {
    const response = await put('/institution/1/office/1', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with valid body', async done => {
    const body = {
      nombre: 'Waku',
      institucion: 1
    };
    const response = await put('/institution/1/office/1', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('office');
    done();
  });

  it('DELETE /:id without credentials', async done => {
    const response = await _delete('/institution/0/office/0');
    expect(response.status).toEqual(401);
    done();
  });

  it('DELETE /:id with invalid institution id', async done => {
    const response = await _delete('/institution/test/office/0', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('DELETE /:id with invalid office id', async done => {
    const response = await _delete('/institution/0/office/test', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('DELETE /:id with non-existent institution', async done => {
    const response = await _delete('/institution/0/office/0', true);
    expect(response.status).toEqual(404);
    done();
  });

  it('DELETE /:id with non-existent office', async done => {
    const response = await _delete('/institution/1/office/0', true);
    expect(response.status).toEqual(404);
    done();
  });

  it('DELETE /:id with valid ids', async done => {
    const response = await _delete(`/institution/1/office/${createdOffice}`, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('office');
    done();
  });
});