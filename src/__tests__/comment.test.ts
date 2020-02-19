import { post, put, _delete } from "@utils/tests";
let commentCreated = 0;

describe('ROUTE /task/:id/comment', () => {
  it('POST / without credentials', async done => {
    const response = await post('/task/0/comment', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('POST / with invalid task id', async done => {
    const response = await post('/task/test/comment', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / with invalid body', async done => {
    const response = await post('/task/0/comment', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / without commenting permission', async done => {
    const body = {
      comentario: {
        descripcion: 'Test'
      }
    };
    const response = await post('/task/0/comment', body, true);
    expect(response.status).toEqual(403);
    done();
  });

  it('POST / with valid body', async done => {
    const body = {
      comentario: {
        descripcion: 'Test'
      }
    };
    const response = await post('/task/2/comment', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('comment');
    commentCreated = response.body.comment.id;
    done();
  });

  it('PUT /:id without credentials', async done => {
    const response = await put('/task/0/comment/0', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT /:id with invalid task id', async done => {
    const response = await put('/task/test/comment/0', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with invalid comment id', async done => {
    const response = await put('/task/0/comment/test', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with invalid body', async done => {
    const response = await put('/task/0/comment/0', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT /:id with valid body', async done => {
    const body = {
      descripcion: 'Test'
    };
    const response = await put('/task/2/comment/1', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('comment');
    done();
  });

  it('DELETE /:id without credentials', async done => {
    const response = await _delete('/task/0/comment/0');
    expect(response.status).toEqual(401);
    done();
  });

  it('DELETE /:id with invalid task id', async done => {
    const response = await _delete('/task/test/comment/0', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('DELETE /:id with invalid comment id', async done => {
    const response = await _delete('/task/1/comment/test', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('DELETE /:id without permissions to delete comment', async done => {
    const response = await _delete('/task/0/comment/1', true);
    expect(response.status).toEqual(403);
    done();
  });

  it('DELETE /:id with permissions to delete comment', async done => {
    const response = await _delete(`/task/2/comment/${commentCreated}`, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('comment');
    done();
  });
});