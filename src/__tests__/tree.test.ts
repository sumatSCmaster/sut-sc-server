import { get, put } from "@utils/tests";
import { Payloads } from 'sge';
import { NestedSetNode } from "ts-nested-set";
import { stringify } from 'flatted/cjs';

describe('ROUTE /tree', () => {
  it('GET / without credentials', async done => {
    const response = await get('/tree');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with credentials', async done => {
    const response = await get('/tree', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('tree');
    done();
  });

  it('PUT / without credentials', async done => {
    const response = await put('/tree', {});
    expect(response.status).toEqual(401);
    done();
  });

  it('PUT / with invalid body', async done => {
    const response = await put('/tree', {}, true);
    expect(response.status).toEqual(500);
    expect(response.body).toHaveProperty('error');
    expect(response.body.message).toBe('Error en datos enviados');
    done();
  });

  it('PUT / with credentials and valid body', async done => {
    const tree = new NestedSetNode('Administrador');
    tree.append(new NestedSetNode('Programador'));
    const body: { flat: Payloads.DatosCargo[], tree: string } = {
      flat: tree.flat(),
      tree: stringify(tree)
    };
    const response = await put('/tree', body, true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('tree');
    done();
  });

  it('GET /children without credentials', async done => {
    const response = await get('/tree/children');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET /tree/children with credentials', async done => {
    const response = await get('/tree/children', true);
    expect(response.status).toEqual(200);
    expect(Array.isArray(response.body.children)).toBeTruthy();
    done();
  });

  it('GET /children/users without credentials', async done => {
    const response = await get('/tree/children/user');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET /tree/children/users with credentials', async done => {
    const response = await get('/tree/children/user', true);
    expect(response.status).toEqual(200);
    expect(Array.isArray(response.body.users)).toBeTruthy();
    done();
  });
});