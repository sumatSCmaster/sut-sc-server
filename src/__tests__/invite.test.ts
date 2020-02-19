import { get, post, _delete, patch, put } from "@utils/tests";
import crypto from 'crypto';
let inviteCreated = 0;

describe('ROUTE /invite', () => {
  it('GET / without credentials', async done => {
    const response = await get('/invite');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with credentials', async done => {
    const response = await get('/invite', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('invitations');
    expect(Array.isArray(response.body.invitations)).toBeTruthy();
    done();
  });

  it('POST / without credentials', async done => {
    const response = await post('/invite', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('POST / with invalid body', async done => {
    const response = await post('/invite', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('POST / with repeated id (cedula) or email', async done => {
    const body = {
      usuario: {
        cedula: 'v-27.139.154',
        nombre: 'Test',
        correo: `gab.trompizcianci@gmail.com`,
        institucion: 1,
        oficina: 1,
        cargo: 2,
        rol: 1
      }
    };
    const response = await post('/invite', body, true);
    expect(response.status).toEqual(409);
    done();
  });

  it('POST / with valid body', async done => {
    const buffer = crypto.randomBytes(7);
    const body = {
      usuario: {
        cedula: buffer.toString('hex'),
        nombre: 'Test',
        correo: `${buffer.toString('hex')}@gmail.com`,
        institucion: 1,
        oficina: 1,
        cargo: 2,
        rol: 1
      }
    };
    const response = await post('/invite', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('invitation');
    inviteCreated = response.body.invitation.id;
    done();
  });

  it('PATCH /:id/resend without credentials', async done => {
    const response = await patch('/invite/0/resend');
    expect(response.status).toEqual(401);
    done();
  });

  it('PATCH /:id/resend with invalid invitation id', async done => {
    const response = await patch('/invite/test/resend', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PATCH /:id/resend with non-existent id', async done => {
    const response = await patch('/invite/0/resend', true);
    expect(response.status).toEqual(404);
    done();
  });

  it('PATCH /:id/resend with valid id', async done => {
    const response = await patch(`/invite/${inviteCreated}/resend`, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('sent');
    expect(response.body.sent).toBeTruthy();
    done();
  });

  it('DELETE /:id without credentials', async done => {
    const response = await _delete('/invite/0');
    expect(response.status).toEqual(401);
    done();
  });

  it('DELETE /:id with invalid id', async done => {
    const response = await _delete('/invite/test', true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('DELETE /:id with non-existent invitation', async done => {
    const response = await _delete('/invite/0', true);
    expect(response.status).toEqual(404);
    done();
  });

  it('DELETE /:id with valid id', async done => {
    const response = await _delete(`/invite/${inviteCreated}`, true);
    expect(response.status).toEqual(200);
    done();
  });
});