import { get } from "@utils/tests";

describe('ROUTE /project', () => {
  it('GET / without credentials', async done => {
    const response = await get('/project');
    expect(response.status).toEqual(401);
    done();
  });

  it('GET / with credentials', async done => {
    const response = await get('/project', true);
    expect(response.status).toEqual(200);
    expect(response.body).toHaveProperty('projects');
    expect(Array.isArray(response.body.projects)).toBeTruthy();
    done();
  });
});