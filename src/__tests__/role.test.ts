import { get, post, _delete, put } from '@utils/tests';
import crypto from 'crypto';
let createdRole = 0;

describe('ROUTE /role', () => {
  it('GET / without credentials', async done => {
    const response = await get('/role');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with credentials', async done => {
    const response = await get('/role', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('roles');
    expect(Array.isArray(response.body.roles)).toBeTruthy();
    done();
  });

  it('POST / without credentials', async done => {
    const response = await post('/role', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('POST / with invalid body', async done => {
    const response = await post('/role', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / with valid body', async done => {
    const hex = crypto.randomBytes(16); 
    const body = {
      permisos: [1, 2],
      nombre: hex.toString('hex')
    };
    const response = await post('/role', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('role');
    createdRole = response.body.role.id;
    done();
  });

  it('DELETE /:id without credentials', async done => {
    const response = await _delete('/role/0');
    expect(response.status).toEqual(401);
    done();
  });

  it('DELETE /:id with invalid role id', async done => {
    const response = await _delete('/role/test', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('DELETE /:id with non-existent role', async done => {
    const response = await _delete('/role/0', true);
    expect(response.status).toEqual(404);
    done();
  });

  it('DELETE /:id with valid role id', async done => {
    const response = await _delete(`/role/${createdRole}`, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('role');
    done();
  });

  it('PUT /:id without credentials', async done => {
    const response = await put('/role/0', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /:id with invalid role id', async done => {
    const response = await put('/role/test', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with invalid body', async done => {
    const response = await put('/role/0', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with non-existent role', async done => {
    const body = {
      permisos: [1, 2],
      nombre: 'Test'
    };
    const response = await put('/role/0', body, true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PUT /:id with valid role id', async done => {
    const body = {
      permisos: [1, 2],
      nombre: 'Test'
    };
    const response = await put('/role/3', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('role');
    done();
  });

  it('GET /permission without credentials', async done => {
    const response = await get('/permission');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET /permission with credentials', async done => {
    const response = await get('/permission', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('permissions');
    expect(Array.isArray(response.body.permissions)).toBeTruthy();
    done();
  });

  it('GET /permission/user without credentials', async done => {
    const response = await get('/permission/user');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET /permission/user with credentials', async done => {
    const response = await get('/permission/user', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('permissions');
    expect(Array.isArray(response.body.permissions)).toBeTruthy();
    done();
  });
});