import { get, post, put, _delete } from "@utils/tests";
let taskCreated = 0;

describe('ROUTE /task', () => {
  it('GET / without credentials', async done => {
    const response = await get('/task');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with credentials', async done => {
    const response = await get('/task', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('tasks');
    expect(Array.isArray(response.body.tasks)).toBeTruthy();
    done();
  });

  it('POST / without credentials', async done => {
    const response = await post('/task', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('POST / with invalid body', async done => {
    const response = await post('/task', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / with valid body', async done => {
    const body = {
      tarea: {
        responsable: 'v-27.139.154',
        fechaEntrega: 1580308637640,
        titulo: 'Test',
        descripcion: 'Test'
      }
    };
    const response = await post('/task', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('task');
    taskCreated = response.body.task.id;
    done();
  });

  it('PUT /:id without credentials', async done => {
    const response = await put('/task/0', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /:id with invalid id', async done => {
    const response = await put('/task/test', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with invalid body', async done => {
    const response = await put('/task/0', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with non-existent task id', async done => {
    const body = {
      titulo: 'Test',
      descripcion: 'Test'
    };
    const response = await put('/task/0', body, true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PUT /:id with valid body and id', async done => {
    const body = {
      titulo: 'Test',
      descripcion: 'Test'
    };
    const response = await put(`/task/${taskCreated}`, body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('task');
    done();
  });

  it('PUT /:id/status without credentials', async done => {
    const response = await put('/task/0/status', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /:id/status with invalid id', async done => {
    const response = await put('/task/test/status', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id/status with invalid body', async done => {
    const response = await put('/task/0/status', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id/status with non-existent id', async done => {
    const body = {
      status: 4
    };
    const response = await put('/task/0/status', body, true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PUT /:id/status with valid body and id', async done => {
    const body = {
      status: 4
    };
    const response = await put(`/task/${taskCreated}/status`, body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('id');
    done();
  });

  it('PUT /:id/rate without credentials', async done => {
    const response = await put('/task/0/rate', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /:id/rate with invalid id', async done => {
    const response = await put('/task/test/rate', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id/rate with invalid body', async done => {
    const response = await put('/task/0/rate', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id/rate with non-existent id', async done => {
    const body = {
      rating: 5
    };
    const response = await put('/task/0/rate', body, true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PUT /:id/rate with valid body and id', async done => {
    const body = {
      rating: 5
    };
    const response = await put(`/task/${taskCreated}/rate`, body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('rate');
    done();
  });

  it('DELETE /:id without credentials', async done => {
    const response = await _delete('/task/0');
    expect(response.status).toEqual(401);
    done();
  });

  it('DELETE /:id with invalid id', async done => {
    const response = await _delete('/task/test', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('DELETE /:id with non-existent id', async done => {
    const response = await _delete('/task/0', true);
    expect(response.status).toEqual(404);
    done();
  });

  it('DELETE /:id with valid id', async done => {
    const response = await _delete(`/task/${taskCreated}`, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('id');
    done();
  });

  it('GET /sent without credentials', async done => {
    const response = await get('/task/sent');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET /sent with credentials', async done => {
    const response = await get('/task/sent', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('tasks');
    expect(Array.isArray(response.body.tasks)).toBeTruthy();
    done();
  });

  it('GET /sent without credentials', async done => {
    const response = await get('/task/toRate');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET /toRate with credentials', async done => {
    const response = await get('/task/toRate', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('tasks');
    expect(Array.isArray(response.body.tasks)).toBeTruthy();
    done();
  });
});