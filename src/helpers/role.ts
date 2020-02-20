import Pool from "@utils/Pool";
import { Rol, Permiso } from "sge";
import queries from "@utils/queries";

const pool = Pool.getInstance();

// export const getRoles = async (): Promise<Rol[]> => {
//   const client = await pool.connect();
//   try {
//     const roles = await client.query(queries.GET_ALL_ROLES);
//     return await Promise.all(roles.rows.map(async (r) => {
//       const permissions = await client.query(queries.GET_PERMISSIONS, [r.id]);
//       return {
//         id: r.id as number,
//         nombre: r.nombre as string,
//         permisos: permissions.rows.map((p) => ({
//           id: p.id as number,
//           descripcion: p.descripcion as string,
//           categoria: p.categoria
//         }))
//       };
//     }));
//   } catch(e) {
//     throw e;
//   } finally {
//     client.release();
//   }
// };

// export const removeRole = async (id: number): Promise<Rol | null> => {
//   const client = await pool.connect();
//   try {
//     const result = await client.query(queries.DELETE_ROLE, [id]);
//     return result.rowCount > 0 ? ({
//       id: result.rows[0].id as number,
//       nombre: result.rows[0].nombre as string
//     }) : null;
//   } catch(e) {
//     throw e;
//   } finally {
//     client.release();
//   }
// };

// export const editRole = async (id: number, name: string, permissions: Permiso[]): Promise<Rol | null> => {
//   const client = await pool.connect();
//   try {
//     const exists = await client.query(queries.GET_ROLE_BY_ID, [id]);
//     if(exists.rowCount === 0) return null;
//     const query = permissions.length > 0 ? queries.EDIT_ROLE_WITH_PERMISSIONS : queries.EDIT_ROLE_WIHOUT_PERMISSIONS;
//     const values = permissions.length > 0 ? [id, name, permissions] : [id, name];
//     const result = await client.query(query, values);
//     return ({
//       id,
//       nombre: name,
//       permisos: result.rows.map((r) => ({
//         id: r.id_funcion as number,
//         descripcion: r.descripcion_funcion as string,
//         categoria: r.categoria
//       }))
//     });
//   } catch(e) {
//     throw e;
//   } finally {
//     client.release();
//   }
// };

// export const createRole = async (permissions: number[], name: string): Promise<Rol> => {
//   const client = await pool.connect();
//   try {
//     const result = await client.query(queries.CREATE_ROLE, [permissions, name]);
//     return {
//       id: result.rows[0].id_rol,
//       nombre: result.rows[0].nombre_rol,
//       permisos: result.rows.map((r) => ({
//         id: r.id_funcion as number,
//         descripcion: r.descripcion_funcion as string,
//         categoria: r.categoria
//       }))
//     };
//   } catch(e) {
//     throw e;
//   } finally {
//     client.release();
//   }
// };

// export const getPermissions = async (): Promise<Permiso[]> => {
//   const client  = await pool.connect();
//   try {
//     const result = await client.query(queries.GET_ALL_PERMISSIONS);
//     return result.rows.map((r) => ({
//       id: r.id as number,
//       descripcion: r.descripcion as string,
//       categoria: r.categoria
//     }));
//   } catch(e) {
//     throw e;
//   } finally {
//     client.release();
//   }
// };

// export const getUserPermissions = async (id: string): Promise<number[]> => {
//   const client = await pool.connect();
//   try {
//     const result = await client.query(queries.GET_USET_PERMISSIONS, [id]);
//     return result.rows.map((r) => r.id_funcion);
//   } catch(e) {
//     throw e;
//   } finally {
//     client.release();
//   }
// };
